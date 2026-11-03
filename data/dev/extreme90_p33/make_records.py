"""Phase 33: write data/dev/ta90_n94.json ... for the boards selected by select33.py (run from the repo root).
Adapted from data/dev/extreme90_p32/make_records.py; the selection itself is select33.py (pre-registered rule)."""
import json, re
D = 'data/dev/extreme90_p33/'
SRC = ('hybrid: hand core frozen cell for cell (seed_%s.json, %s); blocks added by the Phase 25-27 generator '
       '(tools/ta90_search.gd of commit c1ddc89, run in a separate worktree) --ops=v20 with the Phase 25-27 search parameters '
       '(piece_free 13, max_pieces 17, suffix_rate 0.30, patience 8), RNG seed %d, %s; every board then passed the unchanged '
       'modern pipeline: engine-valid tokens, bank overlap (bank incl. N88-N93), tools/extreme90_screen30.py (40 ms gates, strict essentiality, '
       'filler, hint-follow) and the full evaluation tools/extreme90_eval25.py --full; shortlist rule %s; '
       'Phase 33 protocol data/dev/extreme90_p33/protocol.json (the Phase 31 method, unchanged; arm %s)')
CON = {
 'T01r': ('T01r_PULLEDTRIGGER', 'P30 the pulled trigger (magnet + switch)', 'magnet x reversal', 'Phase 30'),
 'T10b': ('T10b_LADDERBLOCK', 'P30 the blocked key ladder (switch + lock)', 'reversal x lock chain', 'Phase 30'),
 'K08': ('K08_PULLEDTARGET', 'P32 the pulled target (magnet + switch)', 'magnet x reversal', 'Phase 32 (never produced a rated board)'),
 'R04': ('R04_ARMOREDKEY', 'P29 the armored key (switch + lock + armor)', 'reversal x lock x armor', 'Phase 29'),
 'J4': ('J4_RELAY', 'P26 the two-hop relay (two magnets + armor)', 'magnet relay', 'Phase 26 (never produced a rated board)'),
 'L3': ('L3_SHELLEXIT', 'P27 the reversal frees the shell (switch + armor)', 'shell face-off', 'Phase 27'),
 'T30': ('T30_TWOKEYS', 'P30 two keys, one reversal (switch + lock)', 'reversal x two locks', 'Phase 30'),
}
HUMAN = {'status': 'NOT YET TESTED', 'difficulty': 'not supplied', 'enjoyment': 'not supplied', 'outcome_90s': 'not supplied',
         'solve_time_ms': 'not supplied', 'attempts': 'not supplied', 'restarts': 'not supplied', 'undo_used': 'not supplied',
         'notes': 'not supplied', 'owner_decision': 'none',
         'how_recorded': 'filled only from the owner\'s first exposure on ?extreme90p33=1 (COPY ALL RESULTS JSON carries time, restarts, Undo, moves, attempts per run) and the owner\'s own ratings; nothing is inferred'}


def mechs(m):
    t = ' '.join(m)
    out = []
    for name, pat in (('magnet', r'\*'), ('switch', r'%'), ('lock', r'#[RBGYP]'), ('armor', r'='), ('gate', r'(\bX[ABCD]\b|\+[ABCD])'), ('sequence', r':'), ('spinner', r'@')):
        if re.search(pat, t):
            out.append(name)
    return out


selraw = json.load(open(D + 'selection_raw.json'))
st = json.load(open(D + 'struct_selected.json'))
tmpl = json.load(open('data/dev/ta90_n62.json'))
sel, fps = {}, {}
for i, x in enumerate(selraw['selected']):
    nid = 'N%d' % (94 + i)
    key = x['key']; seed = int(key.split('_s')[1].split('_')[0]); short = key.split('_')[0]
    core, fam, grp, origin = CON[short]
    where = 'round 1' if seed == 331 else 'round 2 (second RNG seed: no screen PASS in round 1)'
    ev = json.load(open(D + 'ev/%s/eval_%s.json' % (key, key)))
    r = json.load(open(D + 'ev/%s/report_%s.json' % (key, key)))[key]
    fl = json.load(open(D + 'ev/%s/filler_%s.json' % (key, key)))[key]
    cand = json.load(open(D + 'ev/cand_%s.json' % key))[key]
    spec = json.load(open(D + 'specs/seed_%s.json' % core))
    mech = mechs(r['map'])
    adv = {'positions': ev['positions'], 'early3': st[key]['early3'], 'open_tempting': st[key]['open_escape_losing'],
           'p_look2': st[key].get('p_look2'),
           'note': 'ADVISORY ONLY (no predictor met the pre-registered decision rule, validation.json); recorded before any human play; NOT used to select or reject; the owner is the judge'}
    arm = {'arm': x['arm']}
    if x['arm'] == 'R':
        arm.update({'approved_sibling': x['sibling'], 'overlap_to_sibling': x['overlap_to_sibling']})
    s = {'key': key, 'core': core, 'family': fam, 'group': grp, 'mechanics': mech, 'idea': spec['idea'], **arm,
         'related': 'closest occupancy %s %.2f (bank); pairwise with the other Phase 33 boards <= %.2f' % (ev['overlap'][1], ev['overlap'][0], selraw['max_pairwise_overlap']),
         'source': SRC % (core, origin, seed, where, '+'.join(cand['rules']), x['arm']),
         'selection': 'pre-registered rule (select33.py): one board per concept, the fewest positions among the fully qualified boards; pairwise overlap <= 0.30',
         'advisory_prediction': adv, 'human_test': HUMAN}
    sel[nid] = s
    rec = json.loads(json.dumps(tmpl)); b = rec['boards'][0]
    rec['test'] = 'ta90_' + nid.lower()
    rec['note'] = "Development only. Phase 33 EXTREME candidate (?extreme90p33=1); never shared, never production. TECHNICALLY QUALIFIED (Category A and B): NOT human-approved; human difficulty unvalidated."
    b.update({'id': nid, 'variant': nid, 'design': 'P33_' + key, 'family': fam, 'concept_group': grp, 'primary': ', '.join(mech),
              'mechanics': mech, 'idea': spec['idea'], 'source': s['source'], 'related_bank_concept': s['related'],
              'fingerprint': r['A']['fingerprint'], 'label': 'TECHNICALLY QUALIFIED - HUMAN UNTESTED', 'human_test': HUMAN})
    b['puzzle'] = {'format': 'ce-puzzle', 'v': 1, 'rules': 1, 'rows': 7, 'cols': 7, 'map': r['map']}
    b['design_report'] = {'A': r['A'], 'B': r['B'], 'C': r['C'], 'filler': fl, 'similarity': {'closest_known': ev['overlap'][1], 'overlap': ev['overlap'][0]},
                          'structure33': st[key], 'advisory_prediction': adv, **({'arm': arm})}
    for k in list(b.keys()):
        if k in ('advisory_rank29', 'owner_decision', 'human_p31'):
            del b[k]
    assert r['map'] == cand['map'] == x['map'] and ev['verdict'] == 'HUMAN-REVIEW CANDIDATE'
    json.dump(rec, open('data/dev/ta90_%s.json' % nid.lower(), 'w'), indent=1)
    fps[nid] = r['A']['fingerprint']
    print(nid, key, r['A']['fingerprint'][:12], r['A']['solution'], ev['positions'], mech, x['arm'])
json.dump(sel, open(D + 'selection.json', 'w'), indent=1)
json.dump(fps, open(D + 'fingerprints.json', 'w'), indent=1)
