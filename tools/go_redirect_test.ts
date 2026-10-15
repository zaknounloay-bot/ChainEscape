// STABLE CHALLENGE LINKS (Phase 4): tests of the "go" Edge Function.
// Nothing remote: the logic (supabase/functions/go/redirect.ts) is called
// directly, then the real server entry (index.ts) is run under Deno on a
// local port and asked over HTTP (redirects not followed).
//
//   deno run --allow-run --allow-net --allow-env --allow-read tools/go_redirect_test.ts
import { gameTarget, handleGo } from "../supabase/functions/go/redirect.ts";

const results: boolean[] = [];
function check(ok: boolean, msg: string) {
  results.push(ok);
  console.log((ok ? "PASS " : "FAIL ") + msg);
}

const ID = "3f2b8c1e-7d4a-4c55-9e1b-0a6d2c8f9b10";
const ID_UP = ID.toUpperCase();
const PROD = "https://html-classic.itch.zone/html/12345678/index.html";
const QA = "https://html-classic.itch.zone/html/87654321/index.html";
const ENV: Record<string, string> = { CE_GAME_URL: PROD, CE_QA_GAME_URL: QA };
const env = (e: Record<string, string>) => (k: string) => e[k];
const go = (q: string, e: Record<string, string> = ENV, method = "GET") =>
  handleGo(new Request("https://ref.supabase.co/functions/v1/go" + q, { method }), env(e));
const common = (r: Response) => r.headers.get("cache-control") === "no-store" && r.headers.get("referrer-policy") === "no-referrer";

// --- Redirects -----------------------------------------------------------------
let r = go(`?challenge=${ID}`);
check(r.status === 302 && r.headers.get("location") === `${PROD}?challenge=${ID}` && common(r) && (await r.text()) === "",
  `valid id -> 302 to CE_GAME_URL?challenge=<id>, no-store, no-referrer (${r.headers.get("location")})`);
r = go(`?challenge=${ID}&to=qa`);
check(r.status === 302 && r.headers.get("location") === `${QA}?challenge=${ID}` && common(r), "to=qa -> 302 to CE_QA_GAME_URL");
r = go(`?to=qa&challenge=${ID}`);
check(r.status === 302 && r.headers.get("location") === `${QA}?challenge=${ID}`, "parameter order does not matter");
r = go(`?challenge=${ID_UP}`);
check(r.status === 302 && r.headers.get("location") === `${PROD}?challenge=${ID_UP}`, "the id is passed on exactly as given (upper case kept)");
r = go(`?challenge=${ID}&utm_source=whatsapp&fbclid=x`);
check(r.status === 302 && r.headers.get("location") === `${PROD}?challenge=${ID}`, "other link parameters (messenger tracking) are not forwarded");
r = go(`?challenge=${ID}`, { CE_GAME_URL: PROD + "?v=1700000000#top" });
check(r.status === 302 && r.headers.get("location") === `${PROD}?v=1700000000&challenge=${ID}`,
  "the destination's own query (itch ?v=) is kept, its fragment dropped");
r = go(`?challenge=${ID}`, { CE_GAME_URL: PROD + "?challenge=00000000-0000-4000-8000-000000000000&to=qa" });
check(r.headers.get("location") === `${PROD}?challenge=${ID}`, "a challenge / to inside the configured address never overrides the link's id");
r = go(`?challenge=${ID}`, { CE_GAME_URL: "https://chain-escape.itch.io/chain-escape" });
check(r.status === 302 && r.headers.get("location") === `https://chain-escape.itch.io/chain-escape?challenge=${ID}`,
  "a <name>.itch.io page is an accepted destination");

// --- HEAD / methods -----------------------------------------------------------
r = go(`?challenge=${ID}`, ENV, "HEAD");
check(r.status === 302 && r.headers.get("location") === `${PROD}?challenge=${ID}` && common(r) && r.body === null, "HEAD -> the same 302, no body");
r = go(`?challenge=bad`, ENV, "HEAD");
check(r.status === 400 && r.body === null && common(r), "HEAD with a bad id -> 400, no body");
for (const m of ["POST", "PUT", "DELETE", "PATCH", "OPTIONS"]) {
  r = go(`?challenge=${ID}`, ENV, m);
  check(r.status === 405 && r.headers.get("allow") === "GET, HEAD" && common(r) && !r.headers.get("location"), `${m} -> 405, Allow: GET, HEAD`);
}

// --- Invalid ids / routes -----------------------------------------------------
for (const [q, why] of [
  ["", "no parameter"], ["?challenge=", "empty id"], ["?challenge=abc", "not a uuid"],
  [`?challenge=${ID}x`, "trailing character"], [`?challenge=${ID.slice(1)}`, "35 characters"],
  [`?challenge=%20${ID}`, "leading space"], [`?challenge=${ID}&challenge=${ID}`, "repeated id"],
  [`?challenge=${ID.replaceAll("-", "")}`, "no dashes"], [`?challenge=../../evil`, "path characters"],
  [`?challenge=${ID}&to=prod`, "unknown route"], [`?challenge=${ID}&to=toString`, "inherited name as route"],
  [`?challenge=${ID}&to=qa&to=qa`, "repeated route"], [`?id=${ID}`, "wrong parameter name"],
] as [string, string][]) {
  r = go(q);
  check(r.status === 400 && !r.headers.get("location") && common(r), `400 for ${why} (${q || "-"})`);
}

// --- Destination settings: missing / malformed / not itch.io -------------------
const bad: [Record<string, string>, string][] = [
  [{}, "CE_GAME_URL unset"], [{ CE_GAME_URL: "" }, "empty"], [{ CE_GAME_URL: "   " }, "blank"],
  [{ CE_GAME_URL: "not a url" }, "malformed"], [{ CE_GAME_URL: "http://html-classic.itch.zone/html/1/index.html" }, "http"],
  [{ CE_GAME_URL: "https://evil.example/index.html" }, "other host"],
  [{ CE_GAME_URL: "https://html-classic.itch.zone.evil.example/x" }, "suffix trick"],
  [{ CE_GAME_URL: "https://evil.example/html-classic.itch.zone" }, "host in the path"],
  [{ CE_GAME_URL: "https://user:pw@html-classic.itch.zone/html/1/index.html" }, "credentials"],
  [{ CE_GAME_URL: "https://html-classic.itch.zone:8443/html/1/index.html" }, "a port"],
  [{ CE_GAME_URL: "javascript:alert(1)" }, "javascript:"], [{ CE_GAME_URL: "//html-classic.itch.zone/x" }, "scheme-relative"],
  [{ CE_GAME_URL: "https://a.b.itch.io/x" }, "nested itch.io subdomain"], [{ CE_GAME_URL: "https://itch.io.evil.example/x" }, "itch.io prefix trick"],
];
for (const [e, why] of bad) {
  r = go(`?challenge=${ID}`, e);
  const body = await r.text();
  check(r.status === 503 && !r.headers.get("location") && common(r) && !body.includes("evil") && !body.includes("pw"), `503 when CE_GAME_URL is ${why}; nothing of the value in the answer`);
}
r = go(`?challenge=${ID}&to=qa`, { CE_GAME_URL: PROD });
check(r.status === 503 && !r.headers.get("location"), "to=qa with only CE_GAME_URL set -> 503 (never falls back to the production address)");
r = go(`?challenge=${ID}`, { CE_QA_GAME_URL: QA });
check(r.status === 503 && !r.headers.get("location"), "no to with only CE_QA_GAME_URL set -> 503 (never falls back to the QA address)");
check(gameTarget("https://HTML-Classic.Itch.Zone/html/1/index.html")?.hostname === "html-classic.itch.zone", "host check is case-insensitive");

// --- No arbitrary redirect from the request -------------------------------------
for (const q of [`?challenge=${ID}&url=https://evil.example`, `?challenge=${ID}&to=https://evil.example`,
                 `?challenge=${ID}&next=//evil.example`, `?challenge=https://evil.example`]) {
  r = go(q);
  const loc = r.headers.get("location") || "";
  check(!loc.includes("evil"), `no redirect to a request-supplied address (${q.split("&")[1] || q}) -> ${r.status}`);
}

// --- Compatibility with the game's link parsing (ShareLink.parse / social_creator.js)
r = go(`?challenge=${ID}&to=qa`, { CE_QA_GAME_URL: QA + "?v=99" });
const loc = new URL(r.headers.get("location")!);
check(loc.searchParams.get("challenge") === ID && loc.searchParams.getAll("challenge").length === 1 && !loc.searchParams.has("to"),
  "the game receives exactly one ?challenge=<id> (what web/social_creator.js reads), no routing parameter");

// --- The real server entry (index.ts) over HTTP -----------------------------------
const port = 8000;  // Deno.serve()'s default (index.ts sets none, as on Supabase)
const proc = new Deno.Command(Deno.execPath(), {
  args: ["run", "--quiet", "--allow-net", "--allow-env", "supabase/functions/go/index.ts"],
  env: { CE_GAME_URL: PROD, CE_QA_GAME_URL: QA },
  stdout: "null", stderr: "piped",
}).spawn();
let up = false;
for (let i = 0; i < 100 && !up; i++) {
  try { await (await fetch(`http://127.0.0.1:${port}/`, { redirect: "manual" })).body?.cancel(); up = true; } catch { await new Promise((s) => setTimeout(s, 100)); }
}
try {
  const base = `http://127.0.0.1:${port}/functions/v1/go`;
  let h = await fetch(`${base}?challenge=${ID}&to=qa`, { redirect: "manual" });
  await h.body?.cancel();
  check(up && h.status === 302 && h.headers.get("location") === `${QA}?challenge=${ID}` && common(h), "served index.ts: GET -> 302 to the QA address");
  h = await fetch(`${base}?challenge=${ID}`, { method: "HEAD", redirect: "manual" });
  check(h.status === 302 && h.headers.get("location") === `${PROD}?challenge=${ID}`, "served index.ts: HEAD -> 302 to the production address");
  h = await fetch(`${base}?challenge=nope`, { redirect: "manual" });
  await h.body?.cancel();
  check(h.status === 400, "served index.ts: bad id -> 400");
} finally {
  proc.kill();
  await proc.status;
}

const failed = results.filter((x) => !x).length;
console.log(`\n${results.length - failed} passed, ${failed} failed`);
console.log(failed === 0 ? "GO REDIRECT TEST PASSED" : "GO REDIRECT TEST FAILED");
Deno.exit(failed === 0 ? 0 : 1);
