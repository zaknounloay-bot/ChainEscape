"""Phase 31: write data/dev/ta90_nXX.json for the selected boards (run from the repo root)."""
import json, os
D = 'data/dev/extreme90_p31/'
SRC = ('hybrid: hand core frozen cell for cell (seed_%s.json, Phase 30); blocks added by the Phase 25-27 generator '
       '(tools/ta90_search.gd of commit c1ddc89, run in a separate worktree) --ops=v20 with the Phase 25-27 search parameters '
       '(piece_free 13, max_pieces 17, suffix_rate 0.30, patience 8), RNG seed %d, %s; every board then passed the unchanged '
       'modern pipeline: engine-valid tokens, bank overlap, tools/extreme90_screen30.py (40 ms gates, strict essentiality, '
       'filler, hint-follow) and the full evaluation tools/extreme90_eval25.py --full; shortlist rule %s; '
       'Phase 31 protocol data/dev/extreme90_p31/protocol.json (arms, AM1)')
CON = {
 'T01r_PULLEDTRIGGER': ('P30 the pulled trigger (magnet + switch)', 'magnet x reversal', ['magnet', 'switch', 'spinner'],
   'the pulled trigger: a fixed magnet pulls the switch piece into its own cell, so WHEN the magnet leaves decides where the reversal is fired from and which lane it opens'),
 'T27r_TRIGGERLINK': ('P30 the trigger is the last link (switch + gate)', 'reversal x gate', ['switch', 'gate', 'spinner'],
   'the trigger is the last link: the switch piece is also the gate\'s link, so one move both reverses the targets and opens the gate - every target must face the right way before the door opens'),
 'T57_TWOEFFECTS': ('P30 one escape, two effects (switch + spinner)', 'reversal x spinner', ['switch', 'spinner'],
   'one escape, two effects: the switch piece stands beside a spinner, so the same escape turns the spinner AND reverses the targets - which neighbours the spinner faces when the reversal lands decides the order of everything after'),
 'T10b_LADDERBLOCK': ('P30 the blocked key ladder (switch + lock)', 'reversal x lock chain', ['switch', 'lock', 'spinner'],
   'the blocked key ladder: the last prisoner blocks the key\'s only exit, so the key must be REVERSED to leave - and that same reversal turns the locked middle key away from its exit'),
 'T30_TWOKEYS': ('P30 two keys, one reversal (switch + lock)', 'reversal x two locks', ['switch', 'lock', 'spinner'],
   'two keys, one reversal: both keys are flip targets of one switch and each faces its own prisoner; one press turns both, so each key must leave on the right side of the single switch press'),
}
PICK = {'N83': ('A_T01r_s302_2', 'T01r_PULLEDTRIGGER', 302, 'experiment arm A'),
        'N84': ('A_T27r_s302_0', 'T27r_TRIGGERLINK', 302, 'experiment arm A'),
        'N85': ('G_T57_s308_0', 'T57_TWOEFFECTS', 308, 'Phase 31 deeper run (second RNG seed)'),
        'N86': ('G_T10b_s302_0', 'T10b_LADDERBLOCK', 302, 'Phase 31 run (AM1)'),
        'N87': ('G_T30_s302_0', 'T30_TWOKEYS', 302, 'Phase 31 run (AM1)')}
st = json.load(open(D + 'struct_n83_n87.json'))
tmpl = json.load(open('data/dev/ta90_n62.json'))
sel, fps, maps = {}, {}, {}
for nid, (key, core, seed, where) in PICK.items():
    ev = json.load(open(D + 'ev/%s/eval_%s.json' % (key, key)))
    r = json.load(open(D + 'ev/%s/report_%s.json' % (key, key)))[key]
    fl = json.load(open(D + 'ev/%s/filler_%s.json' % (key, key)))[key]
    cand = json.load(open(D + 'ev/cand_%s.json' % key))[key]
    fam, grp, mech, idea = CON[core]
    s = {'key': key, 'core': core, 'family': fam, 'group': grp, 'mechanics': mech, 'idea': idea,
         'related': 'closest occupancy %s %.2f (bank); pairwise with the other Phase 31 boards <= 0.30' % (ev['overlap'][1], ev['overlap'][0]),
         'source': SRC % (core, seed, where, '+'.join(cand['rules'])),
         'selection': 'one board per concept: the fewest positions among the fully qualified boards of the concept (S_old, Phase 25/26 rule; Phase 31 section E)',
         'preregistered_prediction': {'positions': ev['positions'], 'early3': sum(ev['B']['losing_per_step'][:3]),
                                      'open_escape_losing': st[nid]['open_escape_losing'],
                                      'note': 'recorded before any human play; NOT used to select; the owner is the judge'}}
    sel[nid] = s
    rec = json.loads(json.dumps(tmpl)); b = rec['boards'][0]
    rec['test'] = 'ta90_' + nid.lower()
    rec['note'] = "Development only. Phase 31 EXTREME candidate (?extreme90p31=1); never shared, never production. TECHNICALLY QUALIFIED (Category A and B): NOT human-approved; human difficulty unvalidated."
    b.update({'id': nid, 'variant': nid, 'design': 'P31_' + key, 'family': fam, 'concept_group': grp, 'primary': ', '.join(mech),
              'mechanics': mech, 'idea': idea, 'source': s['source'], 'related_bank_concept': s['related'],
              'fingerprint': r['A']['fingerprint'], 'label': 'TECHNICALLY QUALIFIED - HUMAN UNTESTED'})
    b['puzzle'] = {'format': 'ce-puzzle', 'v': 1, 'rules': 1, 'rows': 7, 'cols': 7, 'map': r['map']}
    b['design_report'] = {'A': r['A'], 'B': r['B'], 'C': r['C'], 'filler': fl, 'similarity': {'closest_known': ev['overlap'][1], 'overlap': ev['overlap'][0]},
                          'structure31': st[nid], 'preregistered_prediction': s['preregistered_prediction']}
    for k in list(b.keys()):
        if k == 'advisory_rank29':
            del b[k]
    json.dump(rec, open('data/dev/ta90_%s.json' % nid.lower(), 'w'), indent=1)
    fps[nid] = r['A']['fingerprint']; maps[nid] = r['map']
    assert r['map'] == cand['map']
    print(nid, key, r['A']['fingerprint'][:12], r['A']['solution'], ev['positions'])
json.dump(sel, open(D + 'selection.json', 'w'), indent=1)
json.dump(fps, open(D + 'fingerprints.json', 'w'), indent=1)
