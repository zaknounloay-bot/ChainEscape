"""Phase 32 (development only): the hand cores, written before any Phase 32
generator run. Each core is a small solvable dependency; the Phase 25-27
generator (the Phase 31 method) grows the board around it.
Search parameters are the Phase 31 arm A / AM1 values, unchanged."""
import json, os
D = os.path.dirname(os.path.abspath(__file__)) + '/cores'
E = '. . . . . . .'
BASE = {'target': 'EXTREME', 'facts': [], 'max_positions': 2000, 'piece_free': 13, 'max_pieces': 17,
        'shortcut_weight': 80, 'coverage_weight': 25, 'late_weight': 20, 'endgame_weight': 20,
        'length_weight': 1.0, 'length_cap': 18, 'pressure_weight': 1.5, 'palette': 'all',
        'suffix_rate': 0.3, 'crates_max': 0, 'size': 'medium', 'max_solve_nodes': 1500,
        'spinners_max': 4, 'strict_essential': True, 'token_guard': True, 'core_essential': True}
CORES = {
 'K01_TWOGROUPKEYS': dict(mechanic='switch,lock', suffixes=['&A', '&B', '#Y', '#B'], suffix_max={'&A': 2, '&B': 2, '#Y': 2, '#B': 2},
   idea='two keys, two reversals: each key faces its own prisoner and needs ITS switch; switch A stands in key B\'s exit and blocks switch B, so the two reversals have an order',
   map=[E, '. P^#Y . . . G^#B .', E, '. Y^&A . . . B^&B .', E, '. R>%B . . . R>%A .', E]),
 'K02_PULLEDPRISONER': dict(mechanic='magnet,lock', suffixes=['#Y', '*'], suffix_max={'#Y': 3, '*': 2},
   idea='the magnet frees a deadlock: the key and its prisoner block each other; only a magnet pulling the PRISONER out of the key\'s lane breaks it - so what stands behind the magnet when it leaves decides everything',
   map=[E, E, '. . . P^#Y G>* . .', E, '. . . Y^ . . .', E, E]),
 'K06_TWOGROUPLADDER': dict(mechanic='switch,lock', suffixes=['&A', '&B', '#Y', '#P'], suffix_max={'&A': 2, '&B': 2, '#Y': 2, '#P': 2},
   idea='a two-group ladder: the key must be reversed (A) to leave, its prisoner is itself a key and a flip target of B, and B\'s switch stands in the prisoner\'s exit - firing B to clear the lane turns the prisoner round',
   map=['. R<%B . . . . .', E, '. P^#Y&B . . G<#P . .', E, '. Y^&A . . . . .', E, 'R>%A . . . . . .']),
 'K08_PULLEDTARGET': dict(mechanic='magnet,switch', suffixes=['&A', '*'], suffix_max={'&A': 3, '*': 2},
   idea='the pulled target: a flip target and its switch block each other; a fixed magnet pulls the TARGET into a new lane, and the switch then decides which way it leaves from there',
   map=[E, E, E, '. . . G<* . Bv&A .', E, '. . . . . P^%A .', E]),
 'K16_ARMOREDKEY': dict(mechanic='armor,switch,lock', suffixes=['&A', '#Y', '='], suffix_max={'&A': 2, '#Y': 2, '=': 2},
   idea='the shelled key: the key is armored AND faces its own prisoner, so it needs a ram and a reversal; the rammer is the only piece aimed at the shell',
   map=[E, '. . . Y>&A= . P^#Y .', E, E, '. . . R^ . . .', E, 'G>%A . . . . . .']),
 'K20_RELAYPULL': dict(mechanic='magnet,lock', suffixes=['#B', '*'], suffix_max={'#B': 3, '*': 3},
   idea='the relay pull: two magnets in one column; the first pulls the second, the second pulls the prisoner out of the key\'s row - the relay works only while nothing else is in the column',
   map=[E, '. . R^* . . . .', '. . P^* . . . .', 'B> . G>#B . . . .', E, E, E]),
}
for k, v in CORES.items():
    s = dict(BASE); s.update(v)
    s['family'] = 'P32 ' + k
    s['phase32_core'] = k
    s['frozen'] = [[r, c] for r, row in enumerate(s['map']) for c, t in enumerate(row.split()) if t != '.']
    json.dump(s, open('%s/seed_%s.json' % (D, k), 'w'), indent=1)
    print(k, s['frozen'])
