extends SceneTree
## v0.8 level-design audit for 226-300 (writes Markdown to stdout):
##   godot --headless --path . --script res://tools/era3_audit.gd [-- --from=226 --to=300]
##
## Per level: the idea, mechanics present, difficulty / structural
## difficulty, solution length, start moves, depth, decisions, trap moves,
## random-tapper win rate (how often blind tapping clears it), whether the
## arc's mechanic is essential, breather, and whether it introduces a new
## interaction. Per section: difficulty distribution, averages, hardest,
## breathers, mechanic and interaction frequency. Flags: unexpectedly
## trivial, a jump much harder than its neighbours, a mechanic present but
## irrelevant (impact < 1.0), too similar to the previous level, high
## restart potential (random win ~0 with many traps), clutter (> 22 blocks
## or 4 mechanic families).

const Verify := preload("res://tools/verify_levels.gd")

const IDEAS := {
	226: "First Sequence: first tap turns it, second tap escapes",
	227: "Two Sequence blocks: read the small NEXT arrow",
	228: "Sequence lane through a portal (simple)",
	229: "First stage turns the spinner next to it",
	230: "Sequence + portal, both Sequence blocks matter",
	231: "WHEN: using a first stage too early loses",
	232: "First stage reveals a hidden arrow",
	233: "A Sequence block is a lock's key colour",
	234: "Sequence block cracks a shell",
	235: "BREATHER: easy rhythm of two Sequence blocks",
	236: "First stage turns counter-clockwise / alternating spinners",
	237: "Sequence through a portal, timing traps",
	238: "Three Sequence blocks in order",
	239: "Late first stage; a portal lane blocked far away",
	240: "Two portal pairs with Sequence",
	241: "Echo: first stages and spinners, timing",
	242: "Relay: Sequence blocks through a portal",
	243: "Sequence x Armor: crack the shell with a Sequence block",
	244: "BREATHER: smooth Sequence + portal run",
	245: "Three Sequence blocks, alternating spinner",
	246: "Sequence as lock key, timing traps",
	247: "Long fuse: late first stage, remote portal block",
	248: "First stage reveals the hidden arrow; spinners",
	249: "Pre-milestone: three Sequence blocks, spinners, portal",
	250: "MILESTONE: four Sequence blocks - WHEN to use each first stage",
	251: "First push: the spinner pushes, then turns away",
	252: "Push from two sides; it never has to leave",
	253: "Where it lands: one push blocks you later",
	254: "Push order: who pushes first",
	255: "First real Movable puzzle",
	256: "Two Movable blocks",
	257: "Clear the lane: the wrong push loses",
	258: "BREATHER: soft push",
	259: "Corner pocket: three pushes, a wrong one loses",
	260: "Return trip: pushed both ways",
	261: "Two Movable blocks, many pushes",
	262: "Stopper: a push that blocks a lane forever",
	263: "Two moves ahead",
	264: "BREATHER: easy slide",
	265: "Future lane: two Movable blocks, a wrong push loses",
	266: "A spinner pushes, turns, pushes again",
	267: "Movable x Armor",
	268: "Movable x Portal: push through a portal",
	269: "Movable x Sequence: a first stage pushes",
	270: "BREATHER: sliding door (portal push)",
	271: "Plan ahead: portal + pushes, a wrong push loses",
	272: "Two Movable blocks + a Sequence pusher",
	273: "Hold position: timing of pushes and first stages",
	274: "Pre-milestone: two Movable blocks, portal",
	275: "MILESTONE: choose where the Movable blocks will be later",
	276: "Portal x Sequence, two pairs",
	277: "Portal x Movable: the block travels through a portal",
	278: "Sequence x Movable: first stages that push",
	279: "Sequence x mixed spinners, timing",
	280: "Portal x Armor (with Sequence)",
	281: "BREATHER: open road",
	282: "Movable x Spinner: the spinner is the pusher",
	283: "Hidden door: a first stage reveals; portal lanes",
	284: "Movable x Lock: the key sits behind the block",
	285: "Two-way portals x Sequence",
	286: "Three-way: a Sequence block pushes through a portal",
	287: "BREATHER: easy orbit",
	288: "Gate x Sequence through a portal",
	289: "Ram line: Armor x Movable (a ram and pushes)",
	290: "Half light: Movable with hidden arrows",
	291: "Cold logic: pushes and first stages, both timed",
	292: "Switch x Portal x Sequence",
	293: "Far reach: the Movable block is pushed through a portal",
	294: "BREATHER: clear skies",
	295: "Heavy lock: Movable x Lock x Sequence",
	296: "Clockwork heart: three Sequence blocks, mixed spinners, portal",
	297: "Deep freight: where the Movable blocks end up decides the last lanes",
	298: "Vault: Armor x Movable x Sequence",
	299: "Last mile: two portal pairs, Sequence timing",
	300: "MAJOR MILESTONE: two portal pairs, four Sequence blocks, cw + ccw spinners",
}


func _initialize() -> void:
	var from := 226
	var to := 300
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			from = int(a.get_slice("=", 1))
		elif a.begins_with("--to="):
			to = int(a.get_slice("=", 1))
	var rows := []
	var prev: LevelData = null
	for n in range(from, to + 1):
		if not FileAccess.file_exists(LevelManager.LEVEL_PATH % n):
			continue
		var lv := LevelManager.read_level(n)
		var m := LevelAnalysis.analyze(lv)
		var model := BoardModel.new()
		model.setup(lv.rows, lv.columns, lv.blocks)
		model.set_portals(lv.portals)
		m["random_win"] = snappedf(Solver.from_model(model).random_win_rate(300, 11), 0.01)
		m["struct"] = LevelGenerator.structural_difficulty(m)
		m["fams"] = Verify._families(m)
		m["breather"] = _breather(n)
		m["sim_prev"] = LevelGenerator.similarity(lv, prev) if prev != null and prev.rows == lv.rows and prev.columns == lv.columns else 0.0
		m["n"] = n
		m["level_name"] = lv.name
		rows.append(m)
		prev = lv
	# Flags (need neighbours).
	for i in rows.size():
		var m: Dictionary = rows[i]
		var flags := []
		if m["solution_length"] <= 4 and m["n"] not in [226, 251]:
			flags.append("short")
		if i > 0 and not m["breather"] and m["difficulty"] - rows[i - 1]["difficulty"] > 14.0 and not _milestone(m["n"]):
			flags.append("jump +%.0f" % (m["difficulty"] - rows[i - 1]["difficulty"]))
		for pair in [["portal", m["portal_impact"], m["portal_pairs"]], ["sequence", m["sequence_impact"], m["sequence_blocks"]]]:
			if pair[2] > 0 and pair[1] < 1.0:
				flags.append("%s minor (%.1f)" % [pair[0], pair[1]])
		if m["crates"] > 0 and not m["push_essential"] and m["movable_impact"] < 1.0:
			flags.append("movable minor")
		if m["spinners"] > 0 and m["spinner_impact"] < 1.0 and m["spinner_impact"] < LevelAnalysis.ESSENTIAL:
			flags.append("spinner minor (%.1f)" % m["spinner_impact"])
		if m["sim_prev"] > 0.45:
			flags.append("like previous (%.2f)" % m["sim_prev"])
		if m["random_win"] < 0.01 and m["trap_moves"] > 40:
			flags.append("restart-heavy (traps %d)" % m["trap_moves"])
		if m["blocks"] > 22 or m["fams"].size() >= 4:
			flags.append("busy (%d blocks, %d families)" % [m["blocks"], m["fams"].size()])
		m["flags"] = flags
	print("| # | Name | Idea | Mechanics | Diff | Struct | Len | Start | Depth | Dec | Traps | Rnd win | Essential | Breather | New interaction | Flags |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	var seen_pairs := {}
	for m in rows:
		var fams: Array = m["fams"]
		var inter := []
		for i in fams.size():
			for j in range(i + 1, fams.size()):
				var key: String = fams[i] + "x" + fams[j]
				if not seen_pairs.has(key) and (fams[i] in ["portal", "sequence", "movable"] or fams[j] in ["portal", "sequence", "movable"]):
					inter.append(key)
					seen_pairs[key] = true
		m["new_inter"] = inter
		print("| %d | %s | %s | %s | %.1f | %.1f | %d | %d | %d | %d | %d | %.2f | %s | %s | %s | %s |" % [
			m["n"], m["level_name"], IDEAS.get(m["n"], ""), ", ".join(fams), m["difficulty"], m["struct"], m["solution_length"],
			m["start_moves"], m["depth"], m["decision_points"], m["trap_moves"], m["random_win"], _essential(m), "yes" if m["breather"] else "",
			", ".join(inter), "; ".join(m["flags"])])
	for sec in [[226, 250, "226-250 SEQUENCE"], [251, 275, "251-275 MOVABLE"], [276, 300, "276-300 INTEGRATION"]]:
		var part := rows.filter(func(m): return m["n"] >= sec[0] and m["n"] <= sec[1])
		if part.is_empty():
			continue
		var d := part.map(func(m): return m["difficulty"])
		var st := part.map(func(m): return m["struct"])
		var hard := part.duplicate()
		hard.sort_custom(func(a, b): return a["difficulty"] > b["difficulty"])
		var freq := {}
		var inter := 0
		for m in part:
			for f in m["fams"]:
				freq[f] = freq.get(f, 0) + 1
			if m["fams"].filter(func(f): return f in ["portal", "sequence", "movable"]).size() >= 2:
				inter += 1
		var flagged := part.filter(func(m): return not m["flags"].is_empty()).map(func(m): return "L%d (%s)" % [m["n"], "; ".join(m["flags"])])
		print("")
		print("### %s" % sec[2])
		print("- difficulty: min %.1f, max %.1f, average %.1f; structural average %.1f" % [d.min(), d.max(), _avg(d), _avg(st)])
		print("- hardest: %s" % ", ".join(hard.slice(0, 4).map(func(m): return "L%d %.1f" % [m["n"], m["difficulty"]])))
		print("- breathers: %s" % ", ".join(part.filter(func(m): return m["breather"]).map(func(m): return "L%d %.1f" % [m["n"], m["difficulty"]])))
		print("- mechanic frequency: %s" % ", ".join(freq.keys().map(func(k): return "%s %d" % [k, freq[k]])))
		print("- levels combining two or more of Portal / Sequence / Movable: %d of %d" % [inter, part.size()])
		print("- flags: %s" % ("none" if flagged.is_empty() else "; ".join(flagged)))
	quit()


static func _avg(a: Array) -> float:
	return a.reduce(func(x, y): return x + y, 0.0) / maxf(a.size(), 1)


static func _breather(n: int) -> bool:
	for arc in Verify.ARCS:
		if n in arc["breathers"]:
			return true
	return false


static func _milestone(n: int) -> bool:
	return n in [250, 275, 300]


static func _imp(v: float) -> String:
	return "ESS" if v >= LevelAnalysis.ESSENTIAL else "%.1f" % v


static func _essential(m: Dictionary) -> String:
	var out := []
	if m["sequence_blocks"] > 0:
		out.append("seq %s" % _imp(m["sequence_impact"]))
	if m["crates"] > 0:
		out.append("push %s" % ("needed" if m["push_essential"] else _imp(m["movable_impact"])))
	if m["portal_pairs"] > 0:
		out.append("portal %s" % _imp(m["portal_impact"]))
	return ", ".join(out)
