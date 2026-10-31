"""Phase 28: write data/dev/ta90_nXX.json for the selected boards (run from the repo root)."""
import json, sys
D = 'data/dev/extreme90_p28/'
sel = json.load(open(D + 'selection.json'))
tmpl = json.load(open('data/dev/ta90_n62.json'))
fps, maps = {}, {}
for nid, s in sel.items():
    key = s['key']
    r = json.load(open(D + 'ev/report_%s.json' % key))[key]
    fl = json.load(open(D + 'ev/filler_%s.json' % key))[key]
    ev = json.load(open(D + 'ev/eval_%s.json' % key))
    rec = json.loads(json.dumps(tmpl)); b = rec['boards'][0]
    rec['test'] = 'ta90_' + nid.lower()
    rec['note'] = "Development only. Phase 28 EXTREME candidate (?extreme90p28=1); never shared, never production. TECHNICALLY QUALIFIED (Category A and B): NOT human-approved; human difficulty unvalidated."
    b.update({'id': nid, 'variant': nid, 'design': 'P28_' + key, 'family': s['family'], 'concept_group': s['group'], 'primary': ', '.join(s['mechanics']),
              'mechanics': s['mechanics'], 'idea': s['idea'], 'source': s['source'], 'related_bank_concept': s['related'],
              'fingerprint': r['A']['fingerprint'], 'label': 'TECHNICALLY QUALIFIED - HUMAN UNTESTED'})
    b['puzzle'] = {'format': 'ce-puzzle', 'v': 1, 'rules': 1, 'rows': 7, 'cols': 7, 'map': r['map']}
    b['design_report'] = {'A': r['A'], 'B': r['B'], 'C': r['C'], 'filler': fl, 'similarity': {'closest_known': ev['overlap'][1], 'overlap': ev['overlap'][0]}}
    json.dump(rec, open('data/dev/ta90_%s.json' % nid.lower(), 'w'), indent=1)
    fps[nid] = r['A']['fingerprint']; maps[nid] = r['map']
    print(nid, key, r['A']['fingerprint'][:12], r['A']['solution'])
json.dump(fps, open(D + 'fingerprints.json', 'w'), indent=1)
json.dump(maps, open(D + 'selected_maps.json', 'w'), indent=1)
