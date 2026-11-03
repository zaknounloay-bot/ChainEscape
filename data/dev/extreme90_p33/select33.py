#!/usr/bin/env python3
"""Phase 33 selection: the pre-registered rule (protocol.json allocation.selection), applied mechanically.
One board per concept (core), the FEWEST POSITIONS among boards with verdict HUMAN-REVIEW CANDIDATE
(every gate passed); pairwise overlap <= 0.30 (sim of tools/extreme90_stage2.py), conflicts resolved
by fewest positions; at most 8 concepts, the 8 with the fewest positions. Advisory predictors are
NOT used here.   python3 data/dev/extreme90_p33/select33.py > data/dev/extreme90_p33/selection_raw.json"""
import json, os, sys
sys.argv = ['x', 'data/dev/extreme90_p33', '0']
exec(open('tools/extreme90_stage2.py').read().split('if __name__')[0].replace("P = json.load(open(D + '/protocol.json'))", 'P = {"families": {}}'))
P = 'data/dev/extreme90_p33'
ARM_R = {"T01r": "N83", "T10b": "N86", "T30": "N87", "R04": "N75", "P03": "N64", "L3": "N62", "J1": "N59", "J5": "N61"}
cands = {}
for k in sorted(os.listdir(P + '/ev')):
    if not os.path.isdir(f'{P}/ev/{k}'): continue
    e = json.load(open(f'{P}/ev/{k}/eval_{k}.json'))
    c = json.load(open(f'{P}/ev/cand_{k}.json'))[k]
    if e['verdict'] != 'HUMAN-REVIEW CANDIDATE': continue
    cands.setdefault(k.split('_')[0], []).append(dict(key=k, positions=e['positions'], map=c['map'], mechanic=c['mechanic'], run=c['run']))
for v in cands.values(): v.sort(key=lambda x: (x['positions'], x['key']))
order = sorted(cands, key=lambda c: cands[c][0]['positions'])
chosen, log = [], []
for c in order:
    for b in cands[c]:
        clash = [(o['key'], round(sim(b['map'], o['map']), 2)) for o in chosen if sim(b['map'], o['map']) > 0.30]
        if clash: log.append('%s rejected: pairwise %s' % (b['key'], clash)); continue
        chosen.append(dict(b, concept=c)); break
    else: log.append('%s: no board free of pairwise conflict' % c)
dropped = [x['key'] for x in chosen[8:]]
chosen = chosen[:8]
bank_ = bank()
for x in chosen:
    x['arm'] = 'R' if x['concept'] in ARM_R else 'N'
    if x['arm'] == 'R':
        sib = ARM_R[x['concept']]; x['sibling'] = sib; x['overlap_to_sibling'] = round(sim(x['map'], bank_[sib]), 2)
x_pair = max((round(sim(a['map'], b['map']), 2) for i, a in enumerate(chosen) for b in chosen[i + 1:]), default=0)
print(json.dumps({"rule": __doc__.split('\n')[1:5], "order": order, "conflicts": log, "dropped_by_cap_8": dropped,
                  "max_pairwise_overlap": x_pair, "selected": chosen}, indent=1))
