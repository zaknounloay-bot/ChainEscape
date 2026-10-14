-- Chain Escape - real-player results (Phase 3B-B). ADDITIVE ONLY: three new
-- tables and two functions; shared_challenges, its policies and the
-- challenge-media bucket are not touched. RLS is on with NO policies, and the
-- functions are executable by service_role only: the public (anon) key can
-- neither read nor write any of it - only the chain-escape-api Edge Function
-- (service role, on the server) can.
--
-- Pools: 'prod' (released game) and 'qa' (QA / dev builds) never mix - a
-- player id, its secret and its results all belong to one pool. The Edge
-- Function decides the pool (see CE_PROD_POOL / CE_PROD_ORIGINS there).

-- 1. The 300 frozen campaign levels (data/level_fingerprints.json). Only
--    an ACTIVE (level, fingerprint) pair takes results; a changed level gets
--    a new row and its old results stay apart.
create table if not exists public.ce_level_fingerprints (
  level smallint not null check (level between 1 and 300),
  fingerprint text not null check (fingerprint ~ '^[0-9a-f]{64}$'),
  active boolean not null default true,
  primary key (level, fingerprint)
);

-- 2. Anonymous competitors: the game's random player id plus the SHA-256 of
--    a random secret the game made (claimed on first use). Not an account.
create table if not exists public.ce_comp_players (
  pool text not null check (pool in ('prod', 'qa')),
  player_id uuid not null,
  secret_hash text not null check (secret_hash ~ '^[0-9a-f]{64}$'),
  created_at timestamptz not null default now(),
  primary key (pool, player_id)
);
create index if not exists ce_comp_players_pool_created on public.ce_comp_players (pool, created_at);

-- 3. One best time per player per level: at most 300 rows per player.
create table if not exists public.ce_level_results (
  pool text not null check (pool in ('prod', 'qa')),
  level smallint not null,
  fingerprint text not null,
  player_id uuid not null,
  time_ms integer not null check (time_ms between 300 and 21600000),
  diag jsonb,  -- timing diagnostics (QA pool only)
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (pool, level, fingerprint, player_id),
  foreign key (level, fingerprint) references public.ce_level_fingerprints (level, fingerprint),
  foreign key (pool, player_id) references public.ce_comp_players (pool, player_id) on delete cascade,
  check (diag is null or pool = 'qa')
);
create index if not exists ce_level_results_rank on public.ce_level_results (pool, level, fingerprint, time_ms);

alter table public.ce_level_fingerprints enable row level security;
alter table public.ce_comp_players enable row level security;
alter table public.ce_level_results enable row level security;
revoke all on public.ce_level_fingerprints, public.ce_comp_players, public.ce_level_results from anon, authenticated;

-- Submit one finished attempt. Atomic: the player row is claimed with
-- ON CONFLICT DO NOTHING (a concurrent first submission waits, then reads
-- the winner's secret), and the result is an upsert that only ever lowers
-- the stored time. Returns {status, improved, best_ms, n, faster}.
create or replace function public.ce_submit_result(
  p_pool text, p_level integer, p_fingerprint text, p_player uuid,
  p_secret_hash text, p_time_ms integer, p_diag jsonb, p_max_new_players integer
) returns jsonb
language plpgsql
set search_path = public
as $$
declare
  v_hash text;
  v_improved boolean;
  v_best integer;
  v_n integer;
  v_faster integer;
begin
  if p_pool is null or p_pool not in ('prod', 'qa') then
    return jsonb_build_object('status', 'bad_pool');
  end if;
  if not exists (select 1 from ce_level_fingerprints f
                 where f.level = p_level and f.fingerprint = p_fingerprint and f.active) then
    return jsonb_build_object('status', 'bad_level');
  end if;
  if p_time_ms is null or p_time_ms < 300 or p_time_ms > 21600000 then
    return jsonb_build_object('status', 'bad_time');
  end if;
  if p_secret_hash is null or p_secret_hash !~ '^[0-9a-f]{64}$' then
    return jsonb_build_object('status', 'wrong_secret');
  end if;

  select c.secret_hash into v_hash from ce_comp_players c where c.pool = p_pool and c.player_id = p_player;
  if v_hash is null then
    -- Bounded growth: at most p_max_new_players new competitors per hour per pool.
    if p_max_new_players > 0 and (select count(*) from ce_comp_players c
        where c.pool = p_pool and c.created_at > now() - interval '1 hour') >= p_max_new_players then
      return jsonb_build_object('status', 'busy');
    end if;
    insert into ce_comp_players (pool, player_id, secret_hash) values (p_pool, p_player, p_secret_hash)
      on conflict (pool, player_id) do nothing;
    select c.secret_hash into v_hash from ce_comp_players c where c.pool = p_pool and c.player_id = p_player;
  end if;
  if v_hash is distinct from p_secret_hash then
    return jsonb_build_object('status', 'wrong_secret');
  end if;

  insert into ce_level_results as r (pool, level, fingerprint, player_id, time_ms, diag)
    values (p_pool, p_level, p_fingerprint, p_player, p_time_ms, case when p_pool = 'qa' then p_diag end)
    on conflict (pool, level, fingerprint, player_id) do update
      set time_ms = excluded.time_ms, diag = excluded.diag, updated_at = now()
      where excluded.time_ms < r.time_ms
    returning true into v_improved;

  select r.time_ms into v_best from ce_level_results r
    where r.pool = p_pool and r.level = p_level and r.fingerprint = p_fingerprint and r.player_id = p_player;
  select count(*), count(*) filter (where r.time_ms < v_best) into v_n, v_faster
    from ce_level_results r where r.pool = p_pool and r.level = p_level and r.fingerprint = p_fingerprint;
  return jsonb_build_object('status', 'ok', 'improved', coalesce(v_improved, false),
    'best_ms', v_best, 'n', v_n, 'faster', v_faster);
end;
$$;

-- Read-only: this player's stored best on a level and where it stands now.
-- Returns {status: 'ok' | 'none' | 'wrong_secret' | 'bad_level', best_ms, n, faster}.
create or replace function public.ce_level_standing(
  p_pool text, p_level integer, p_fingerprint text, p_player uuid, p_secret_hash text
) returns jsonb
language plpgsql
stable
set search_path = public
as $$
declare
  v_hash text;
  v_best integer;
  v_n integer;
  v_faster integer;
begin
  if not exists (select 1 from ce_level_fingerprints f where f.level = p_level and f.fingerprint = p_fingerprint) then
    return jsonb_build_object('status', 'bad_level');
  end if;
  select c.secret_hash into v_hash from ce_comp_players c where c.pool = p_pool and c.player_id = p_player;
  if v_hash is null then
    return jsonb_build_object('status', 'none');
  end if;
  if v_hash is distinct from p_secret_hash then
    return jsonb_build_object('status', 'wrong_secret');
  end if;
  select r.time_ms into v_best from ce_level_results r
    where r.pool = p_pool and r.level = p_level and r.fingerprint = p_fingerprint and r.player_id = p_player;
  if v_best is null then
    return jsonb_build_object('status', 'none');
  end if;
  select count(*), count(*) filter (where r.time_ms < v_best) into v_n, v_faster
    from ce_level_results r where r.pool = p_pool and r.level = p_level and r.fingerprint = p_fingerprint;
  return jsonb_build_object('status', 'ok', 'best_ms', v_best, 'n', v_n, 'faster', v_faster);
end;
$$;

revoke all on function public.ce_submit_result(text, integer, text, uuid, text, integer, jsonb, integer) from public, anon, authenticated;
revoke all on function public.ce_level_standing(text, integer, text, uuid, text) from public, anon, authenticated;
grant execute on function public.ce_submit_result(text, integer, text, uuid, text, integer, jsonb, integer) to service_role;
grant execute on function public.ce_level_standing(text, integer, text, uuid, text) to service_role;

-- 4. The 300 level fingerprints (generated from data/level_fingerprints.json
--    by tools/competition_migration.mjs - do not edit by hand).
-- BEGIN FINGERPRINTS
insert into public.ce_level_fingerprints (level, fingerprint) values
  (1, 'b12b814e6fec4e057c1ce2bc02a4d89b753348f62dfe8efc351d5a8b9aabc7ed'),
  (2, '8e74516dee0d067414b2121e661db2c39ffb85fd1ab2a0763e638232ca6db14d'),
  (3, '208b7cd85bd37f88bb39dfeba95deb871c585641bfa8abd6dd7fcf1075706d0b'),
  (4, '2740b2f0e3f3934b129c2160b795d40ed2b895405a33ca857265a1c9634a591c'),
  (5, '585d6640c57828f95bde88b8e951f04c7417f154824eecb3fc27337634463cef'),
  (6, '89779e9f2583bf031c5a0759b1eff98834d357b45af8d1ef0d85c6794d4a7196'),
  (7, '22ffafb56a2710d56832523c9f12ee323ad1ac295fa25ef7497a0ea065a2370c'),
  (8, '6f5c9c3889e50a031fb61c3782aad54dbe7a5f8ba96bff6d1287b87de9b9131f'),
  (9, '7bc4fa7f7e3991faa90b71104962177d36bcda26c99753f4f5b1382182315e3b'),
  (10, 'ea2ad8c0f4bfbf8e300203efa22193a37ee11d35cb98e9f265fc7ba5a3c32394'),
  (11, '1b131ee3a3fe0165a8ec26b5e173f8f2c17ea2aedf0dc8e5cbec07d3e1b14340'),
  (12, '13d1c5e02d3065fa6bcec316515fb84dc23c19327559b4429db4c72c830225e1'),
  (13, 'e26e08226348f2583c837c40318418021be6443436ee192f64f3b6d18b02482e'),
  (14, 'c645fbd923fc60ad91ae97e9099bbc14c575eeb5f643f8957d95b84a1cfa5d97'),
  (15, '7345f37c3ee433f4f51370bb56b007b509a7de62e2c8044c17f59e5f5c0e94d7'),
  (16, '6c8040f3047f1afbade668da8f2dcca9c0d6726b7d9ded50921ff06168e975cf'),
  (17, '08c181fc56c9e2808a348d7b14ac4612b5db26035d1245b211de1201f8977833'),
  (18, 'db221d00ed580650aab953670ce857f44cc1337871365c1985ec18f9c8ea902e'),
  (19, '3da2055f43bd6529b4dc483b581b2fba5f2b883877f7c07e0bdc6abde941f36f'),
  (20, 'f54815d910d29662e662edc2445df8167aa78f6a1f7653f966115be8dba60f73'),
  (21, '212c21b5276632ab1d88568a74d31a1c9096b4e9b1fb0f908fe4879ffffdd719'),
  (22, '81559e0a7d1a18966c58195e44f5c5864929ea3f0a0ca0c9d378c2e74dfbb78e'),
  (23, 'add434919090a23f4b50dddcf7ebbcacd2eb14b791ee16c2fa61af7ccb4a129a'),
  (24, 'c2918dd3df1e562394be970ba603ea8680c6401366307095f50c87788e30020f'),
  (25, '7316733d3879d75254cb7f843ed267674905a53d571ea489c3870ea40c03dc94'),
  (26, 'c17819397b6f05ac2e593fef6f15fe02ef15b8b9ea0e8731d9020223d87fd006'),
  (27, 'd15798495abfcc08410131135889fcc3488e5a729110e3f53321f05362a74092'),
  (28, '468a4849d4afa4e23a8cae4d84a5fbf8a13cfbdbcb1a9a19035b97ce398a9abd'),
  (29, '9949f72745e6a90eb65a526a04b12fedbab562d3b5191a0b47716f868ffbe792'),
  (30, 'fd354c9d8dd30591db2c1d574dbe85a1a12e66fcd2cfc62c296849fa0e6cc7fb'),
  (31, 'f6a737e8d4c4793b5b501014625c7c1dab8bbf4005cc406bd9bb8638ab6bfccb'),
  (32, '856fe6cba16d95c40672be5fc61512ab11dc1f37e074fec0c6f96c4c615a24fe'),
  (33, 'a195ac90fe64e336773b9951679bec282fda278743b597852a60e952d25917a3'),
  (34, '80c77d76985b72799322482ce6fdb59156acf84c2587e20b1bcd4412a4af3b87'),
  (35, '7bc9acb7e111317c0e162b58b84c4b37c01b97d1f27957968e2f7942dbd04748'),
  (36, '05e2c239bc43597151568048408d17292199268d242f9ad861b12c05c0827918'),
  (37, 'a55e4b7c872c6beaa7b4a613c564931a23f99e0014158846310fc2caa366aded'),
  (38, 'f6c450a101ffa2b8810905a403abbfc80c4186e06be7e49066c688f48327c09f'),
  (39, 'fd0172628e9e6691c301e245e7f15f492e5536447cccbfe8d24a3235c9e0dc78'),
  (40, '75f8e9eba93d07866ad1aa16975b60021551ba3d76ddbff9da88c0c1ca3a6693'),
  (41, '0f076938917e4ffa9d71d1466c1578850cbf9f8d2491dfeba206065529f0cd3e'),
  (42, '3328d9b0a1c9a687b8a70fc792a51fc5f2ee85d55ff65bdd969d956eb4e1f158'),
  (43, '973e4e1211f80dc23e0cb589636424b53d4760db01b5d08dd12d0a5f46d0dba1'),
  (44, '7abeb6e9cfbd3a4b40c0ff8d59cb8a661346fc32155983b5f974e19230de09bc'),
  (45, '9a9b3c26830a8b9caaf99da889fe39f94216ec05631028f42fff7bbcb4295da3'),
  (46, '7a43a601956fe564a44573e2d93b22fe247b8c6fb0950aab097285fb6c71350f'),
  (47, '6557407d2bc7fb0ac88a915421f2ac04578a4d2bb4bd001d551757ce4c75aaba'),
  (48, '546643d52c478dd1dad7d05eba1b373eabd3da63d583ef7f73dccedc18466ce0'),
  (49, '0f0f10440d6f0d3fc912a94e0a385fec6f6f71e2208ce6b7d4ca2e6016c7c230'),
  (50, '859056152bf4db83b2da5074847d9a360ee3f8d755280a23c56f3116d92316cd'),
  (51, '0c551117ac50223e5be4d52aacc5747bb6eade721f006dadec48aa647487a7e8'),
  (52, '411d1b5363f730297c2ced6fef0426f67e90b171ff87b9a25dbd4f5bd97d4059'),
  (53, '2604e7a4825c6f9b60b869e36f0520c5262597d7503429a09996696aa52197ab'),
  (54, 'cc75ae81081a6857d149100fefb2c6f3f70d941ee354828d557c1a4bfb037ce7'),
  (55, '15514248b7173a81fe9b3a8d1a1354cb85dbbee21e7c850df64b6f0ddeb90dc8'),
  (56, '9f2257cbb375521e069aaf31cbd6fd2e61eccf3cb52784673e08b1f6a9073d85'),
  (57, '5519e31056ab74c46ba6151c10125a2f026d0a31114dbbb11f21f203b858d927'),
  (58, '61e9c04a74e85df97d53f7e1857bac9c65c1252c32b76a5ebdfc2ee5103adade'),
  (59, '68293674b8cdc276a006ab1f9447e4344d333020c54039081e16b41b299fcb1d'),
  (60, 'e8b897a3c917e3b9cb8ea36331e5142d8c0be6527af15cd54170f58e7d8e4bf2'),
  (61, 'fb897036d48490ed1f7947daa7d73593cad59f39be438538ffc3a0b3da9f6d7d'),
  (62, '1216d9f1f5cba482a00f1a6367664b6cbc0885ea96eaaaefed90b5187c26844e'),
  (63, 'b85cb84a1b5b10127622c3d481b83067b86b618882565f391079796eadbe8841'),
  (64, '23d6d3e0a1f523fc10deeba769ef732ced8f8b023a0e6c3b3038e676468a46a6'),
  (65, '2250d73aade21d06f19ff9572cd7e052a9042adcef4867d32554680ab05e6302'),
  (66, 'bb917d68171a9fc82d6312a4bd202a771fff907af481d57a5bc644b8b0924dd8'),
  (67, '88846feb79d0d6a78df47af55580b7512ebc34fa8567e9abab32a004e885d260'),
  (68, '10a68c4dc8db53eabc1e55c3bcefbf1c86a26751c062c0b50127c96e26087fc5'),
  (69, 'c001d040b4de01a99e7d642bc3f0905c190377a503ab905ccee9da4c6dba7df6'),
  (70, '730680cc0cd931b47f2daaf70234feeafc2c4450db3e2a727dd005b108bf8447'),
  (71, '5b2ebaee95ac73e0e834b29cbecdeb9216686d3c1e1bbaf4a238355e61092eec'),
  (72, '4e6a58cb2337503acacb6fd755b63d0cc0f3f468c79e4ee5e7bfcd56968cafee'),
  (73, '1c59a8298453f4805acf65dd4883d63d9f9cb761faea2cb3021d6681e1983a0e'),
  (74, '253bde9d622017d80ac50af810cb28c8506bdfab83227c38e5b48ea4f9e457c0'),
  (75, 'a08ddd6f99a2757fba9baf56b8ec460250d26ffbc136265bcf41073a8d2099d7'),
  (76, 'ea3552413b4d9aeed2726812879b0276bc10aaef794548c04da6a3759f0059bd'),
  (77, '20f098f7637bd6f73eeffcae20a8d22a381fd2c3d3e5251b95ec13fb62aed0a6'),
  (78, 'af0fdfaaaa9e694009cdf1500e93b8aa387407758ebcda66fda387545e2d05b0'),
  (79, 'acfd2096001eda88ffc39d256864261c1b16119ab509af14d4fc1c994a693a8d'),
  (80, '14aa505657a426c045dced34519abceea09b9cb215fc563106f90f3be24de81d'),
  (81, '56816fca23a33da7893b291073d8b8c2834862030ddb0ce533394aa3c85be3c6'),
  (82, '5193858e83ce8b0504c1fe7ea44676715e9b0b8cc1e53c89e643cebb7605f3bc'),
  (83, 'e9f6bdc620fb55ae7873000f7bf9ea05a50e2e09e13f612b0cfd32efd00e61a3'),
  (84, '5f89c1881b84285b72884a16bbab1eb8e8f281200c2c0de9f216bc95535cde99'),
  (85, '2e1c83adab63705ecc5ebf9568ce5ade651d1eecfbab9e29c04b75cbbc1a4984'),
  (86, '472b99107cc608ca3f763f17de5b35fabd649df80ebea013dc8ab5d555f16cca'),
  (87, '301a28c57fa9af7a9ac7afe4ec89558a4eb64ac7b03a2d893708e84ab38cde93'),
  (88, 'bcc5b3461e41c597ef39728c282c2f9c3bcf11c150bf3d88f4d2682e61148b52'),
  (89, 'd6532e7e38f2738a012acdcfc10fadc511d7e8b3cca2a8ecf47362837cde829c'),
  (90, '185af6389dbfe9b843fbce0f1738cc557f34b1fde36711bb73feec046bdc3196'),
  (91, '6b424556e44d4b7e9b883ea720afb17183a227dc90ba45725b50261b367a9aaa'),
  (92, '05d1f85f0d644581ce66af4c0061de78cc9145c887d060a1315e67361b6ddcf3'),
  (93, '3e23c17d41773c1e00c592b1500d3b73c6582bd3bf678b12f0aa881636f1ff58'),
  (94, '30ddba432bb7287b8f473bf89710f0bd3d05259c35f3c4700fce63b80ed7fa6d'),
  (95, 'dc5387153884f8cc48f1458f4c7aa9d3d6a4bd55e46289725789ace1daced5bc'),
  (96, '68aab3ac2dc0bba1671cdc44adccdab257ff3c694a8d74a9b83b6ea3971cff81'),
  (97, 'b2f1cd1f8059455ff6632b8fea88d421c773eff2f4bc31d7dab693496a2e692e'),
  (98, 'da5226daeefbcf3f6ab3d0a72a6e5eae800bbd05b3ab46475b24228430ec6881'),
  (99, '7b8cb5137fb487a13651a5af8d911991679bbb054092cc425662df71b18f5d6b'),
  (100, '6a5d251b48fd6ef8ffef466e4120101d735f5df1c73bf3869456612791ec0303'),
  (101, 'be879ede69b32e5af5ec7d995ef47ada1a5c7dec35083746a61d288574d27210'),
  (102, '3ae60261600819efb7feb4f119654ed010285d5784e567d8b4702eaf2e0101ed'),
  (103, 'd31927504fb355147700eec5224740f8cad2a13e3bcc8accb77c66386056081f'),
  (104, '4eed6f792ac7fd5abc7317f47bb92ade23dc5d5c9a92da371c2d039a74e3bde0'),
  (105, 'c38c498fbc1eb36516d342364f129fe3c7aeaccb7d25b1e296699ad2b9c09041'),
  (106, 'd87ab913952f67e5e7cf071705e16a554fc2efd919ae1c5882d36af84c17529e'),
  (107, '88af6495768a5f1f0df41bdf23f1188afcdc5dcbfb110d5e40bb07de0e8a3908'),
  (108, 'f021991596bba888daa989d1d08f4c2e8bc940c34512bea016c168666db91571'),
  (109, 'e0af8e4d518614be43e0199334ea9e05b3b43e7019a03e455358abbcbdf591ac'),
  (110, 'd1e258a58145a11733b66adbc6b3cd7b65c14c8e1e90788a48aace7874d58998'),
  (111, '8873f9261c10e1d493e1a22284247e1527198f1ab15076257e29fa5827c6173f'),
  (112, 'b7ec69b03bdcc5fcc94d96a5702e74d21003558dc407bb000ef17e740489e7ef'),
  (113, 'ef6da635f89981cbd3f8e6c9c1e2c2a817853ec25cb5b8d4651a4a7b7211ab41'),
  (114, '485ea818194c33fa73134b74f32d687e8300cd28a87acd4cf88ec4a29e290f99'),
  (115, 'fddf6224a6fdc6d87d92381558f6580ca754426650f9c024421d2af2d36c7dff'),
  (116, 'c12e5d76308cb8746e92ebf6c85f369dfb53924413afb7b3ceffe2cdf9ba9194'),
  (117, '9b48349102a5dcdf3ee0b320cc203f36fd0e8b802eb55391db33b49612736bd8'),
  (118, 'a7c2fa31be89a7385930f58a9d5c093f8bad58b93dc260fbf2ff7764366598ea'),
  (119, 'f160f07610654cca6cb93b7f3363845ef557908cd9208d7b29de5b682bb5a693'),
  (120, '72465864ef58028a3686cd6045d456792dffe8248aa831a7d6d390365ef17783'),
  (121, '9616afcc56819ea374ac656c51ed53abfc5daa85d27c5489786e151421720ba6'),
  (122, '90c0c9b02570173fbad39bb7fcc2c4587086313f9fbae606bc20ab3f9086f303'),
  (123, '452d264d574a5881db12bb99af7822e643bb02e0c7761b59527409f3b1a96ccd'),
  (124, '67f03601c0f415bde266c07a25048fdcc2cbe916922fd84107758f757575b86a'),
  (125, 'c3c3e48dd5f7b08a2fce97952289ea01a7e1edf4d4c5f1e5ef227889854f45b2'),
  (126, '312567f80a90ceaa695453cebe00d5711dde405712217c82602caef35329e793'),
  (127, '35ec5c7e264269a75df8066a1943b0933925ddb0143b377f2ab927c1ac099993'),
  (128, '3363049190c844118c4c23c22bed16aa6b5e498b799044ba6963b66dbf456134'),
  (129, '31865ecda69bc98ab2d4b50e45c58e440a3d1eb0dbf359d2ae21f767822fd4bc'),
  (130, '01f5e00fc3296ae95724899ffd1c3dffed1077f0dfd250fa1726bf4705a8a5ab'),
  (131, 'e97d235e31924df1925240e33dcf274da957dbf3e2e31e5e9f570f72744cba43'),
  (132, 'b43dd5c4be5d91ca7c71140152f4206d3dc8b755fb4aadb685e718a5adb099e1'),
  (133, '0f5b2f9e475d5392330278691bf8bc6f3f96ea1945bbaa0c4e742b5e95b4a5f4'),
  (134, 'a454b3fec752afb2396e97964f6ecca7e076864d266407381d579a4014e986f8'),
  (135, '06e7de7734d3288e5a4cd260dd1a74fecd1be0c41cd138bd6db59158bde419b5'),
  (136, '9728b3e016f5e1a6c8b555fd62335250053b97570524c098c00f44c2ea9ffef7'),
  (137, 'dd403bffeb7dc92c794a428bc1595cd42e48fb359f2966b8c3d70756f571f508'),
  (138, '55da7deaf7fa93cb6283f3744969df5b5dc221c80934e1f9f512bd9519e9b792'),
  (139, '567e5bf1774624e1d1b7697c5d411358c695978188babf7cef8e642187502a8f'),
  (140, '93438cf6f2d2be3702ce516bfd5cc6d3bd5052f3955d1ca8aee8fc24f7fcb47f'),
  (141, '6a14e583177a4345070929aa1cf20788f03fab296ddcf0b8f8705da1c20eab11'),
  (142, '05976b81ad2c833cacef86003f7a223afe4ba98d78ce79ee7610b12438c6eecc'),
  (143, 'e28f3335a4fff9d46726a0ea5267d966df5fddbba7354f65f48dadfae312cebc'),
  (144, 'cb77d4696a822888eb706e0be69de10d4855f125f4fb7524db38a938131d2443'),
  (145, 'f8950b9345e2f072249d9087469135262666ad2bfa18e012b93cf59c43547134'),
  (146, 'ad631c9984ca58ecbe1ae39a929cb4143620c1868f3328c783da8348c0ef98d6'),
  (147, '3a95b6e79a1dfa74669679d0c2904474a594d75d0174a8e6fc12ca90c1c0519f'),
  (148, '9a19bc7b6820e48c684cc900dbeaee02ea89d415a0105dc04e2a7873512a4871'),
  (149, '8a7479f7616e45831489b28409e3107be62134a6989fc97a860edf0ae08fd6f3'),
  (150, '1a53206ec4c62af2caeb34696f7e5784c9a41d754e9653cd29295fe902345faa'),
  (151, 'ba8d496c9626264e721d12d76d2587b185a182de601470c1f613bfaf46df7949'),
  (152, 'c96ae8cc76feb5759db3824fa06f1f29b6c0d13ddb94db7761634329d0bd85fb'),
  (153, '6199bba8d30903f6037328bd5088d7a3df37d24acef356a616dd2f7c08ad70cc'),
  (154, 'dc8a70602e9296e9a410fe8485987bd126ba4a31b466fe45cbdf806571624f7c'),
  (155, '7eefab6014fda6067be0ee0b5dc0fd53db8e316e91ec02b22221ccebfa785146'),
  (156, '02ccff4c3cf410506a26eae1e6686113ba3020e424c5fd9e7f475bb4789ce665'),
  (157, 'f1ffda8db695ab3e1c0b2d532bfca06e322870589799d74a186e658d9261ec8d'),
  (158, 'c53088bf045ca94c33d6992181ed5d83066c1956c820a26e4355d9cc000aa305'),
  (159, '0f97c2525382ce95cf33f80bf391ff7182dad816349b62e749f4d45b921328a6'),
  (160, '1835f07073f3440e5cff3d6d48d01907ada0cdd754673cadbd4fed4adf76e9b7'),
  (161, '1d492092b6d449d014e314839b9a653795645bec4efe4205adef4da6bff1661c'),
  (162, '418f990fd5646f5b228abc6fb4ed5189ff3997199a27ddc9f11c017b514f35e5'),
  (163, '4d17df5095901762586cba360240b9a56cc025e5b1fbe3ca9f29c8ce9a11070a'),
  (164, 'e8e60a54315f3b6f41ca26b4e7d13797b84db61bf743db47f6695ea48b80679d'),
  (165, '929e9d64e6f0940fc4ecf4173df285632809fd6abdecdb6cc612892988ad782d'),
  (166, '521b6d745de581b8b3d290d87668daead629c191f69e7d1e6067a94ff0396c95'),
  (167, '041eb6cc32468cecef77843729c21740576e35330e63c35816b207e410547450'),
  (168, 'c65982c464b3f7d2271bcbdfbfbaa0b7bca5ba702a2fc155c2fb7106e7c15138'),
  (169, 'ce763a689c60f1060be363e16f8d595a0737ec9127b6bc5641d44aae13f11e8e'),
  (170, '133ad32d21c5e30b23474ec5c67b3b6954d619eee875c4518fe1269aa397ca5d'),
  (171, '13160551445ff2a20dc0940139f8ba554c0f425243bdea6bf53552e2b4ed56a7'),
  (172, 'dcdb4d9c392e75c15c1e5e02cd1d5a44566f8674ea1ca72f97a69828b4a7d9ab'),
  (173, '19780a7c6055f3d02aaf60127c09b0d879338df5ebe3967393efb44837732150'),
  (174, '975ccf54ad5ceadae29b88b0e8445754d86d7b41b8b58665d0b966a55b9112e4'),
  (175, 'f72eb53cdf034490424a5d3d7cfd0afa63d989073a6f272f9924cccdb5cef746'),
  (176, '3839089f896ea8b05f633dbc88543f16ee2de32c1057394a923faece6f75fac9'),
  (177, '8f2a90de22f8fb19a4da5726d0327513ab00b497df2b68c8e04ac7a4e0133ff6'),
  (178, 'e43a6e80c84c3f2fe6486afde2d0fac935d2c61a2ea70c5f0ac7af53283f1b6e'),
  (179, '2896f2cf5593066b611fde7f7f3180c57114431973b8d21076877add92af7e80'),
  (180, '1d3ee40f9eacd1d3f6dd8359cf841128cf19d4352bcf7fa43e5eb32a31875535'),
  (181, '60598be5ffbadf13841e16cd127f099b98a0c1cad89c79d9c3f30e74e8bb2bb3'),
  (182, 'ed0a09b1c60399d8b0b89e2f92fbf2fe55472d373f949ab1e511a157a463975a'),
  (183, 'd018888407e3fbc474b59091f539bcbafcdbe774e5051b061779cf93707bb50d'),
  (184, '7afc823acd8959ec8b73858f5ff81f96788b9a96660e066dc44fe97a07ca094e'),
  (185, '33c74fcf3bb00874727d07742b190b20d9d3ee5dca86335a3eb6df0be301e1b8'),
  (186, 'f011e938f18a51951bd04d174fb955442c99f049df0a82720053cb0bb317c698'),
  (187, '3c81d5350b7e4c5c7489eaa52d3d32d8840b5e85c9ddfb1f6ef33c3e20eac2b8'),
  (188, 'b0eb48e5bb372b5c832efb5e7ce50d0e5a750307490aa63ab6958aa26bd075cd'),
  (189, '84774bda56dc370283c848a28b19fa608e93709082b40db26d3ba80c1cca2d26'),
  (190, 'd7a9bd6cdb41493d72f09c5d2ed871ebb861eb40224023102e003d8132f02aff'),
  (191, '099b1d6f4042c5f948c5fea9de97967d2987d78e65c3352a74e1f8e08206fda0'),
  (192, '43a6c7e4014ad661d7638f4a0625d6715273c0ab68171cdfc14ba152883550a9'),
  (193, '16f084ecbb2574be32719b8157ba33cd43ec654ff95b004a4fcd58704e2f7fda'),
  (194, 'a8f67397f3e965a895893fc6586b748cdd326ad74e4d554cfc36e1f5d7664fd9'),
  (195, 'dc678d9a2ee8e1f2a49e7057c9a37814e75835966c018fecc4f448e6411070d0'),
  (196, '6df3db746e9be1175922867b184bf42307778fb1309948fa010a01d1222fe692'),
  (197, 'c2ce82627dad7cb7a4480a23d966bc14ce4c65f3e472459a2c11d56ebc8dc481'),
  (198, 'dda6102fa1c3bf63429fc76b6126e01cf5587b120681fd4f3b6ea88541cf7d3e'),
  (199, 'bf8cae888033624b56b1560b9ffdd8e61c50daa3ac8b40c7c28a2466b1dd5058'),
  (200, '54681301f5b11a178347b09735c8e0f073d4099874689cebf00ec73f75a40690'),
  (201, '94c0cd85e3f348b5eb04c4dbaa86537a76efe17679ec6d81f3f17c0f5c3f246c'),
  (202, 'e694d7f3f6fd3b8fc54a5c19e80ffee462e6f53c6605712995ecb13e74740d66'),
  (203, '8552bb889ea75ca391412f2c4bfd16540a6c0da8a45f5a40e81276e67cc2e9d2'),
  (204, '0ecf2e2060a9f6ff9d6db150129715a8875b1565393164b1b40b1a15816d0ea4'),
  (205, 'fcdc47a7d5848f8f0c38fd40ea99a633e0146d9ede6cd4ece0e17b797bb7cf13'),
  (206, '5b4ae28adb0df63297ca3dfa45b046ed9e7e0b81b584ee4944cfa23f10b27103'),
  (207, '511c848899a3c3a4edf68e5d786086cd53b6c186c2235d02ae9272ca7aa8c6de'),
  (208, '16422d4924d8d638a01273aec776d07472b98a880a1d946ade5a3df01fd31f70'),
  (209, '31d00a4a7a6b987ca2152c6fe7b3b6126ca75ae9dd6a000ba0e11229d6f3eee8'),
  (210, '1c94d1c6a1a443c1eef66fc1aa19674c9d824c7f3e77c491eee842515e9dbb31'),
  (211, '4ec91e41a6e2eb8ae90cfefa875bd4b421dcb4061fbfd98efa94833873c6b3ed'),
  (212, 'e51ce017d26033a37122331b4e3c3df2b57daac14d4ec65dad9e5505a76bbaae'),
  (213, '975fc87b1e1dbb72e90e31532757d2d87e603f5b598ff7fc45ab7b036535cf32'),
  (214, '2111dab4475cec0cf244be557b8e8cf5b8ad6bc44393f99f483f4dc16c814324'),
  (215, '9ee6c8170a2c84d1fe17d2bab6aa4a645733011e646bf0ee344f00c6f6ac21df'),
  (216, '206264f373ca40d43a693d01c0368163af05715ad9c7391103691d9fad48ecd8'),
  (217, '0d5c96eac066777346b2b716789c88fda0691d04dd1bd51dfc5f9fe1bb9ab970'),
  (218, 'c98fedf655c36d6244b64d5bad25dae9b1c4111811fe871a3bba3dcf9f3c8439'),
  (219, 'e322411f975a5f4838a15e64976f8729a9b476e70a175198fd63f8457156ae86'),
  (220, '542a873667cc8e40e3549040c9f90852e423db6bb1fd43c9d2efc655ada70098'),
  (221, '41a99004b233dc1b02021d6f7c1c8042a76e76bd8ec49c76d3ec99e1006144ec'),
  (222, 'c93777c86d0fda7968b15f3562952c26c0ef22b33ffc30c5e5cfd04c0cc43e84'),
  (223, '5466d092dee31c2de2c8d7b7b6322d1efd506b91cf5e12d9eda46b3be4f7de80'),
  (224, '55408868bef6aa9263526fb3003a9aac7859d8994a904b5108b24d16df2a332e'),
  (225, '44b76af190d4a4ad6f91787319736886c1e5cb3a9af470ceab6437d6e2e9dd23'),
  (226, '585d3132063bac995301062cdae8b0c5dfe4209f41bca3c28bbf086f59ff1442'),
  (227, 'd63102f3e30a96b2a39978cad7caa15297f8ac2628f9dd81763d5346a2c740a3'),
  (228, '08f546721b2c6692d9156ce9e35801da927c1411a8d32c98b7dcd6ab14073053'),
  (229, 'c2e064742499f8abe100b5fee59b06902bf4456d96e25e02118897ad58cee98e'),
  (230, 'b5b422e3c885c82356de265b1802c5c3d06d48a1761330faf70038248837c9ce'),
  (231, 'a2e82f25dfb5077a768d3b277aa78edfb663a0a7bbf4595f18c9076555689c5a'),
  (232, '0c26f9f3a3eb9d4f5bb9f912754eb7ab3e6a24bfb2b6e692f67114e662645788'),
  (233, '4ac929a824182293e6b8bffcde2cf7ddcbfc29a55006252e2116ccb472cee24d'),
  (234, 'e0eb44f92d4b70d74ae3c761c5980be4e1d75f333fa73eef6979ec46f762d49e'),
  (235, 'dd6805e885b3206892da060402fa360fef88997f3ca1e8654c42cb5500d66912'),
  (236, 'd336662d089af32729fe3d9846686d0dcf50566d97438cde9b3859505354b5bf'),
  (237, 'df9416b6367669217dfba70ceba575684c3bc303f6c88e035e47721dffe3b914'),
  (238, 'cd7f92c11f1afbac3b2993dfa32c60b9b26dbffe95a6734a177bdbb8e07f9b24'),
  (239, '202e7ea08c457dbaaba95a4fd4131c9d93f5c5f98a2d9485cd326685c89a56bd'),
  (240, 'ed0c049b4f00fb8e285e319758db7b966141c4952ef6544f70483e0d57aafab0'),
  (241, '6af1fdcc16be91864b7272fe042d63ca3cc3c068c212b925b5590f40822fc532'),
  (242, 'f066d7343093ae4c5c7f2b2d71d449f8b85cfbc41aee259697c17afdab72f7c6'),
  (243, '7c0ecaf5ae74c43365b909e939db46af843bb42e3ed2c2cefc2fa25bc08fb991'),
  (244, '8f5e5e90e39bdc8a320dfca9b2df0be7a1f50538f1a78b5b860b05a82bc7b763'),
  (245, 'c382233ac1c8423e487d1d906f3141568f84b3ef88bb9bc0224d06a4f2930e5d'),
  (246, '72104e7a7ab222ed6070ff05ecbbce49e02324986d591ccb9c00a000acb66430'),
  (247, '76f0f445b9a3d0dfddcccca6d98681b0f17cd1f0c2b59b8352c106e08483fc0f'),
  (248, 'f829ad834326e61281c58c2ff077907fd2f20ecc0425564739c0d313bac2f17b'),
  (249, 'c6e9c25fe7d890ed0405d9cef80f673e4970ae0f40a9fd44dc116ca488153c8e'),
  (250, 'dc5747dcc734b966d3581f2761f8eab89f5e4150ceaa06831018ccfa50f458fd'),
  (251, 'cf0a8fd8078d51b08d58ad9827726a8dd1f088bd8e902d802e3397c5e1bb0f83'),
  (252, 'a770d844b83f1150f164e5341642e3a96bc88a82233548617d6b9071383fcf51'),
  (253, '9547b877951ead1235d9ac551cb7b432d4bd65727e6e917c9ad53ef770553c07'),
  (254, '741178642726c53b69b5ba88a8a10e3467961365e293c54b96ddba882a39d5f7'),
  (255, 'e402bcbb77c549ab137b9d18dc9d4116e606e0be5097120ae39e4b0452fc0ab2'),
  (256, '2b29d6a9ccbcfad785a87b142bd4d91dd92e6e5414f0ea585fdd3bfea625bac7'),
  (257, '81284eee9914402e32041fc72589d7768e2f132db7941d93b7f6bbe5bd1c0701'),
  (258, '1eea2ed2e1921f7096376e672b5e1d3d8e2e01091140debb20bbb3b6262f95f2'),
  (259, '86092981af01d3dac4c864507e9478d8fe365190934a7626bea0add218fc04ab'),
  (260, '91386749689fc5c56aa0cae45c48ecb6fbdfa79f030b26a8cd3259e2e11777d7'),
  (261, '344566c94c1d73f5fbf6f2fee5492962006dddf7c6ea11ad6c635083cc3a2288'),
  (262, 'ba47c489c400353cf2e3ded60d428dfc3d9437dd03f17d181fbe53dc32b5b1bb'),
  (263, '41ceb3b06b044c3597bfee2f413b708abd110936a5c604d4ccbfd06208cdd882'),
  (264, '7a7e16bf7be00a8d5415c2ab273e2a4f626bba6fa5da394935d1d5ce96cc2973'),
  (265, 'a08bc39220cf0f25467029baf6c459609ab7baad291ebcb2547c059d5fa161c4'),
  (266, '9fb101f9a0f890aafb9b3fc63e8f1bb072bbf098836876f07b6fb8b439129a54'),
  (267, '64c21dd1bae869052bc7de2313ff0a121371cb0b84ab70affcf92689221b06aa'),
  (268, 'a6e47162e839af7afa37ca28c8db11fd064e9574cb3ce217beab904adb3eab2d'),
  (269, 'c46b782e85fd780b95bb49d0868362b9d2b1403b33aaaa21967b673f33e5605e'),
  (270, '39cede62c083c67e2e8c5bf98976b3cfb8588e215522ace8a3d68f20b85264a9'),
  (271, '5d9faa9b557c44cb756d7ea9a1960792dbfd540bd4598a5e7d2eb968616fb5a0'),
  (272, '232f58d04923c5b924ef44fcbbb3167d696e5dce12b3ddb9da3f3d15dd31fd28'),
  (273, '4108364b086eb19f5e6b2edd948ca19fe27e03f5d4500651a47dd4feee32f079'),
  (274, '6ed398b58618211238e45215ba3d5103ea937d1a4bd0c253dea9ffd92b1566c5'),
  (275, '4347e791f1fbd7a776accb0d4704d6367ef4bfad1ed0e20663b4e5d61dd08f7a'),
  (276, 'b23b0b734f3fa2fa0c749412303d70d7a46cfc23c4a8f7bb108f76235e8cd436'),
  (277, '98e916a94218d9ac2ae76de9d153216add822f3f169484bde64a1512a2322579'),
  (278, '44dff993ccc739f5076e130d6fa3a398d95dd4cba04bf4fc62fc412001053d54'),
  (279, '135a16ce2fae037ec4478eae996ae2d1b73db1c772304430c8dd6e21eeebb240'),
  (280, 'c1d4e289cbdab2519a7c4862f803efb993a4703e6cdc16dbfb2c09f5bea04d4d'),
  (281, '4042fc71660aefe8ba5c41c272885b4d356a472ec9d069b0af988e790e335fbd'),
  (282, '48f7722b5f9621754d94a0749aa00def731294c2fe1908cb4def81e0c525bdff'),
  (283, 'f4262c3bc7b08b7a37bb61fe858794cec9d264394cdd456d74018029954a5613'),
  (284, '15c9fb9182f936a316e3276ae07ad41510656ea41acb008863c86f5b7263ddb8'),
  (285, 'a21d5523db6b739baa30685829d15ee1f69dfb236ea0c318c49247a63a26aba0'),
  (286, '500735e10945ab58a63d91bd24e7d81726bdca365a8cb37b42318ce7dc23965b'),
  (287, '4968c1a006955624734ecc6fb0b8097139cb6e54e24cdd9af2e10e53d4987b91'),
  (288, '6444d29cf2e76c88eeb60635e0df93ec3318e76875c0e684d9b7dc9d42a14e9f'),
  (289, '29ebf12922ce8cb13dbe3b7df57c03ec0a1719d12fb37875bca266d43c6268cc'),
  (290, '7bd77f9f742e9158210e69c964720fdeac2c247260392c5a756b105bc45f93df'),
  (291, 'a37c7856aac3ead7fa1beabf6561e717a20166d57c02c2eb633cf3551413bad6'),
  (292, '7df4d7956fc1efe1b77e31952a5db798352486da3b8bf4760e85dd24314edbbd'),
  (293, '4cbbff6f5528e4070fa74ea12a96e76a519e49c5e6e2d77ac8aaee9fc87a93a6'),
  (294, 'e19eb915c6a74942934fed5f99be42e941010c453d79865228f75231036de73f'),
  (295, '40f78e2ae8a7a9855445d199733f82d2b7c9bf3aafdd83ed63c159f45bd9c452'),
  (296, 'b0ffe0692a4b2ad188b8c5758403df3093ea3547623e936468e6b0d3789d2519'),
  (297, '37d2d86a1f827a1590501e44cfeaafc2ab86d4c89ca430b18e478022f650e588'),
  (298, '0e0970ba647629c1c786c6b27120cbe39b9daa8b1523d6d0d4c225965a7648ab'),
  (299, '119baf79872671b98206710bf44e18de925f62b9c750a94e04ab08adde5077d6'),
  (300, 'd7d4cc91dd7e7995d88529ffd16696d9947cd1e30b11b641e51881e0ddbb1de5')
on conflict (level, fingerprint) do nothing;
-- END FINGERPRINTS
