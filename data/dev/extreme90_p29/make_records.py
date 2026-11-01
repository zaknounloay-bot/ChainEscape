"""Phase 29: write data/dev/ta90_nXX.json for the selected boards (run from the repo root)."""
import json, os
D = 'data/dev/extreme90_p29/'
sel = json.load(open(D + 'selection.json'))
tmpl = json.load(open('data/dev/ta90_n62.json'))
fps, maps = {}, {}
def find(k, what):
    for f in (D + 'ev1/%s/%s_%s.json' % (k, what, k), D + 'ev/%s_%s.json' % (what, k)):
        if os.path.exists(f):
            return json.load(open(f))
for nid, s in sel.items():
    key = s['key']
    r = find(key, 'report')[key]
    fl = find(key, 'filler')[key]
    ev = find(key, 'eval')
    rk = json.load(open(D + 'rank/rank_%s.json' % s['rank_file']))[key]
    rec = json.loads(json.dumps(tmpl)); b = rec['boards'][0]
    rec['test'] = 'ta90_' + nid.lower()
    rec['note'] = "Development only. Phase 29 EXTREME candidate (?extreme90p29=1); never shared, never production. TECHNICALLY QUALIFIED (Category A and B): NOT human-approved; human difficulty unvalidated."
    b.update({'id': nid, 'variant': nid, 'design': 'P29_' + key, 'family': s['family'], 'concept_group': s['group'], 'primary': ', '.join(s['mechanics']),
              'mechanics': s['mechanics'], 'idea': s['idea'], 'source': s['source'], 'related_bank_concept': s['related'],
              'fingerprint': r['A']['fingerprint'], 'label': 'TECHNICALLY QUALIFIED - HUMAN UNTESTED'})
    b['puzzle'] = {'format': 'ce-puzzle', 'v': 1, 'rules': 1, 'rows': 7, 'cols': 7, 'map': r['map']}
    b['design_report'] = {'A': r['A'], 'B': r['B'], 'C': r['C'], 'filler': fl, 'similarity': {'closest_known': ev['overlap'][1], 'overlap': ev['overlap'][0]},
                          'advisory_rank29': {k: rk[k] for k in ('flags', 'gmax', 'look6', 'p_calm', 'forced_share', 'dep_depth')}}
    json.dump(rec, open('data/dev/ta90_%s.json' % nid.lower(), 'w'), indent=1)
    fps[nid] = r['A']['fingerprint']; maps[nid] = r['map']
    print(nid, key, r['A']['fingerprint'][:12], r['A']['solution'], rk['flags'])
json.dump(fps, open(D + 'fingerprints.json', 'w'), indent=1)
json.dump(maps, open(D + 'selected_maps.json', 'w'), indent=1)
