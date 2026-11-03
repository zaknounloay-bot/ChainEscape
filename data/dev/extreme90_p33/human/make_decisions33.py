"""Phase 33 owner decision (project owner, 2026-11-03): N94, N99 APPROVED;
N96 NOT APPROVED at this stage; N95, N97, N98, N100 NOT APPROVED.
Writes owner_decisions_n94_n100.json, updates the decision / label fields of
the N94-N100 records and selection.json, and the bank manifest. Never touches
puzzle maps, fingerprints or the human ratings."""
import json, hashlib
P = 'data/dev/extreme90_p33/'
DATE = '2026-11-03'
DEC_FILE = P + 'owner_decisions_n94_n100.json'
DEC = {'N94': 'APPROVED', 'N99': 'APPROVED', 'N96': 'NOT APPROVED',
       'N95': 'NOT APPROVED', 'N97': 'NOT APPROVED', 'N98': 'NOT APPROVED', 'N100': 'NOT APPROVED'}
NOTE = {'N96': 'NOT APPROVED at this stage (owner); was BORDERLINE - REQUIRES OWNER JUDGMENT'}
human = json.load(open(P + 'human_p33.json'))
prev = json.load(open(P + 'owner_status_n94_n100.json'))

def rec_path(n): return f'data/dev/ta90_{n.lower()}.json'
def frozen(b): return hashlib.sha256(json.dumps([b['puzzle'], b['fingerprint'], b.get('human_test', {}).get('difficulty'), b.get('human_test', {}).get('enjoyment'), b.get('human_test', {}).get('outcome_90s')], sort_keys=True).encode()).hexdigest()

hb = human.get('boards', human)
boards, before = {}, {}
for n, d in DEC.items():
    r = json.load(open(rec_path(n))); b = r['boards'][0]
    before[n] = frozen(b)
    h = b['human_test']
    boards[n] = {'decision': d, 'player_rating': h['difficulty'], 'enjoyment': h['enjoyment'], 'outcome_90s': h['outcome_90s'],
                 'previous_status': prev['boards'][n]['status'], 'fingerprint': b['fingerprint']}
    if n in NOTE: boards[n]['note'] = NOTE[n]
    b['label'] = 'TECHNICALLY QUALIFIED - OWNER APPROVED (Phase 33 owner decision)' if d == 'APPROVED' else 'TECHNICALLY QUALIFIED - HUMAN TESTED, NOT APPROVED'
    b['owner_decision'] = {'decision': d, 'recorded': DATE, 'file': DEC_FILE}
    h['owner_status_before_decision'] = h.get('owner_status_before_decision', h['owner_status'])
    h['owner_status'] = 'OWNER APPROVED' if d == 'APPROVED' else ('NOT APPROVED AT THIS STAGE' if n == 'N96' else 'NOT APPROVED')
    assert frozen(b) == before[n]
    open(rec_path(n), 'w').write(json.dumps(r, indent=1) + '\n')

sel = json.load(open(P + 'selection.json'))
for n, d in DEC.items():
    h = sel[n]['human_test']
    h['owner_status_before_decision'] = h.get('owner_status_before_decision', h['owner_status'])
    h['owner_status'] = ('OWNER APPROVED' if d == 'APPROVED' else ('NOT APPROVED AT THIS STAGE' if n == 'N96' else 'NOT APPROVED'))
    h['owner_decision'] = d
open(P + 'selection.json', 'w').write(json.dumps(sel, indent=1) + '\n')

out = {'source': 'Phase 33 owner decision message (project owner): explicit final decisions on the Phase 33 boards, stored SEPARATELY from the player ratings (human_p33.json, unchanged) and from technical qualification.',
       'recorded': DATE, 'boards': boards, 'acceptance': '2 / 7',
       'count': {'approved_before': 38, 'approved_now': 40, 'target': 50, 'remaining': 10,
                 'reconciled': '38 (Phase 31: N83, N86, N87 on top of 35; Phase 32: 0) + N94, N99 = 40'},
       'supersedes': P + 'owner_status_n94_n100.json (interim recommendation status, kept as history)',
       'unchanged': 'every earlier owner decision; N82 still pending an explicit decision; all fingerprints, puzzle maps and human ratings'}
open(DEC_FILE, 'w').write(json.dumps(out, indent=1) + '\n')

prev['superseded_by'] = DEC_FILE + ' (final owner decision ' + DATE + ': N94, N99 APPROVED; N95-N98, N100 NOT APPROVED; approved bank 40/50)'
open(P + 'owner_status_n94_n100.json', 'w').write(json.dumps(prev, indent=1) + '\n')

# Bank manifest (classification only; records are never deleted).
M = 'data/dev/extreme90_bank_status.json'
m = json.load(open(M))
def add(key, ids):
    for i in ids:
        for k in ('owner_approved', 'strong_provisional', 'provisional', 'technically_qualified_untested', 'borderline_not_approved', 'downgraded_or_archived', 'pending_owner_decision'):
            if k in m and k != key and i in m[k]: m[k].remove(i)
        m.setdefault(key, [])
        if i not in m[key]: m[key].append(i)
add('owner_approved', ['N83', 'N86', 'N87', 'N94', 'N99'])
add('borderline_not_approved', ['N80', 'N96'])
add('pending_owner_decision', ['N82'])
add('downgraded_or_archived', ['N78', 'N79', 'N81', 'N84', 'N85', 'N88', 'N89', 'N90', 'N91', 'N92', 'N93', 'N95', 'N97', 'N98', 'N100'])
m['note'] = ('Authoritative EXTREME bank status. Reconciled 2026-11-03 with every per-phase owner decision file: '
             'extreme90_p29/owner_decisions_n71_n77.json (35), extreme90_p31/owner_decisions_n83_n87.json (+N83, N86, N87 = 38), '
             'extreme90_p32/owner_decisions_n88_n93.json (+0), extreme90_p33/owner_decisions_n94_n100.json (+N94, N99 = 40). '
             'N78-N82 classified from the Phase 31 report (N80 borderline, N82 pending, N78/N79/N81 outside the bank). '
             'Development only. Records are never deleted; this manifest only classifies them.')
m['updated'] = DATE
keys = ['owner_approved', 'strong_provisional', 'provisional', 'technically_qualified_untested', 'borderline_not_approved', 'pending_owner_decision', 'downgraded_or_archived']
m['counts'] = {k: len(m.get(k, [])) for k in keys}
m['counts']['remaining_to_target'] = m['target'] - len(m['owner_approved'])
open(M, 'w').write(json.dumps(m, indent=1) + '\n')
print(m['counts'])
