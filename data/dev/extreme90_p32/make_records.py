"""Phase 32: write data/dev/ta90_nXX.json for the selected boards (run from the repo root)."""
import json, re
D = 'data/dev/extreme90_p32/'
SRC = ('hybrid: hand core frozen cell for cell (seed_%s.json, %s); blocks added by the Phase 25-27 generator '
       '(tools/ta90_search.gd of commit c1ddc89, run in a separate worktree) --ops=v20 with the Phase 25-27 search parameters '
       '(piece_free 13, max_pieces 17, suffix_rate 0.30, patience 8), RNG seed %d, %s; every board then passed the unchanged '
       'modern pipeline: engine-valid tokens, bank overlap, tools/extreme90_screen30.py (40 ms gates, strict essentiality, '
       'filler, hint-follow) and the full evaluation tools/extreme90_eval25.py --full; shortlist rule %s; '
       'Phase 32 protocol data/dev/extreme90_p32/protocol.json (the Phase 31 method, unchanged)')
CON = {
 'K01_TWOGROUPKEYS': ('P32 two keys, two reversals (switch A + switch B + lock)', 'reversal x reversal x lock',
   'two keys, two reversals: each key faces its own prisoner and needs ITS switch; switch A stands in key B\'s exit and blocks switch B, so the two reversals have an order', 'Phase 32'),
 'T03r_PULLTHEKEY': ('P30 pull the key (magnet + lock)', 'magnet x lock',
   None, 'Phase 30'),
 'K02_PULLEDPRISONER': ('P32 the pulled prisoner (magnet + lock)', 'magnet x lock (deadlock)',
   'the magnet frees a deadlock: the key and its prisoner block each other; only a magnet pulling the PRISONER out of the key\'s lane breaks it - so what stands behind the magnet when it leaves decides everything', 'Phase 32'),
 'K06_TWOGROUPLADDER': ('P32 the two-group ladder (switch A + switch B + lock)', 'reversal x reversal x lock chain',
   'a two-group ladder: the key must be reversed (A) to leave, its prisoner is itself a key and a flip target of B, and B\'s switch stands in the prisoner\'s exit - firing B to clear the lane turns the prisoner round', 'Phase 32'),
 'K20_RELAYPULL': ('P32 the relay pull (two magnets + lock)', 'magnet x magnet x lock',
   'the relay pull: two magnets in one column; the first pulls the second, the second pulls the prisoner out of the key\'s row - the relay works only while nothing else is in the column', 'Phase 32'),
 'K16_ARMOREDKEY': ('P32 the shelled key (armor + switch + lock)', 'armor x reversal x lock',
   'the shelled key: the key is armored AND faces its own prisoner, so it needs a ram and a reversal; the rammer is the only piece aimed at the shell', 'Phase 32'),
}
PICK = {'N88': ('K01_s321_3', 'K01_TWOGROUPKEYS', 321, 'round 1'),
        'N89': ('T03r_s321_0', 'T03r_PULLTHEKEY', 321, 'round 1 (Phase 30 core, new RNG seed)'),
        'N90': ('K02_s321_6', 'K02_PULLEDPRISONER', 321, 'round 1'),
        'N91': ('K06_s321_3', 'K06_TWOGROUPLADDER', 321, 'round 1 (K06_s321_2, fewer positions, failed the shortcut gate)'),
        'N92': ('K20_s322_2', 'K20_RELAYPULL', 322, 'round 2 (second RNG seed: no screen PASS in round 1)'),
        'N93': ('K16_s322_11', 'K16_ARMOREDKEY', 322, 'round 2 (second RNG seed: no screen PASS in round 1)')}
HUMAN = {'status': 'NOT YET TESTED', 'difficulty': 'not supplied', 'enjoyment': 'not supplied', 'outcome_90s': 'not supplied',
         'solve_time_ms': 'not supplied', 'attempts': 'not supplied', 'restarts': 'not supplied', 'undo_used': 'not supplied',
         'notes': 'not supplied', 'owner_decision': 'none',
         'how_recorded': 'filled only from the owner\'s first exposure on ?extreme90p32=1 (COPY ALL RESULTS JSON carries time, restarts, Undo, moves, attempts per run) and the owner\'s own ratings; nothing is inferred'}


def mechs(m):
    t = ' '.join(m)
    out = []
    for name, pat in (('magnet', r'\*'), ('switch', r'%'), ('lock', r'#[RBGYP]'), ('armor', r'='), ('gate', r'(\bX[ABCD]\b|\+[ABCD])'), ('sequence', r':'), ('spinner', r'@')):
        if re.search(pat, t):
            out.append(name)
    return out


st = json.load(open(D + 'struct_n88_n93.json'))
tmpl = json.load(open('data/dev/ta90_n62.json'))
sel, fps = {}, {}
for nid, (key, core, seed, where) in PICK.items():
    ev = json.load(open(D + 'ev/%s/eval_%s.json' % (key, key)))
    r = json.load(open(D + 'ev/%s/report_%s.json' % (key, key)))[key]
    fl = json.load(open(D + 'ev/%s/filler_%s.json' % (key, key)))[key]
    cand = json.load(open(D + 'ev/cand_%s.json' % key))[key]
    fam, grp, idea, origin = CON[core]
    spec = json.load(open(D + 'specs/seed_%s.json' % core))
    idea = idea or spec['idea']
    mech = mechs(r['map'])
    s = {'key': key, 'core': core, 'family': fam, 'group': grp, 'mechanics': mech, 'idea': idea,
         'related': 'closest occupancy %s %.2f (bank); pairwise with the other Phase 32 boards <= 0.28' % (ev['overlap'][1], ev['overlap'][0]),
         'source': SRC % (core, origin, seed, where, '+'.join(cand['rules'])),
         'selection': 'one board per concept: the fewest positions among the fully qualified boards of the concept (Phase 31 method)',
         'preregistered_prediction': {'positions': ev['positions'], 'early3': sum(ev['B']['losing_per_step'][:3]),
                                      'open_escape_losing': st[nid]['open_escape_losing'],
                                      'note': 'recorded before any human play; NOT used to select; the owner is the judge'},
         'human_test': HUMAN}
    sel[nid] = s
    rec = json.loads(json.dumps(tmpl)); b = rec['boards'][0]
    rec['test'] = 'ta90_' + nid.lower()
    rec['note'] = "Development only. Phase 32 EXTREME candidate (?extreme90p32=1); never shared, never production. TECHNICALLY QUALIFIED (Category A and B): NOT human-approved; human difficulty unvalidated."
    b.update({'id': nid, 'variant': nid, 'design': 'P32_' + key, 'family': fam, 'concept_group': grp, 'primary': ', '.join(mech),
              'mechanics': mech, 'idea': idea, 'source': s['source'], 'related_bank_concept': s['related'],
              'fingerprint': r['A']['fingerprint'], 'label': 'TECHNICALLY QUALIFIED - HUMAN UNTESTED', 'human_test': HUMAN})
    b['puzzle'] = {'format': 'ce-puzzle', 'v': 1, 'rules': 1, 'rows': 7, 'cols': 7, 'map': r['map']}
    b['design_report'] = {'A': r['A'], 'B': r['B'], 'C': r['C'], 'filler': fl, 'similarity': {'closest_known': ev['overlap'][1], 'overlap': ev['overlap'][0]},
                          'structure31': st[nid], 'preregistered_prediction': s['preregistered_prediction']}
    for k in list(b.keys()):
        if k in ('advisory_rank29', 'owner_decision', 'human_p31'):
            del b[k]
    assert r['map'] == cand['map'] and ev['verdict'] == 'HUMAN-REVIEW CANDIDATE'
    json.dump(rec, open('data/dev/ta90_%s.json' % nid.lower(), 'w'), indent=1)
    fps[nid] = r['A']['fingerprint']
    print(nid, key, r['A']['fingerprint'][:12], r['A']['solution'], ev['positions'], mech)
json.dump(sel, open(D + 'selection.json', 'w'), indent=1)
json.dump(fps, open(D + 'fingerprints.json', 'w'), indent=1)
