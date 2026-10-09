class_name FriendBench
extends CanvasLayer
## Developer page (Challenge a Friend, phase 1): measures puzzle generation
## ON THE DEVICE, the way the creator will run it - one step() slice per
## frame - for each difficulty, NEW CHALLENGE included. Opens only when the
## page address has ?friendbench=1 or #friendbench=1 (desktop:
## "-- --friendbench"); never
## touches Classic, the save or the network. Results are shown on screen
## and published as window.chainEscapeFriendBench.

const RUNS := 8
const PARAM := "friendbench"

var _out: Label
var _again: PillButton
var _running := false
var results: Array = []


## Checked before a shared-challenge link, so it wins even when the address
## also has ?challenge=. Read by the page script (web/social_creator.js,
## which splits parameters on ? & #), with the address itself as a fallback.
static func requested() -> bool:
	if BuildFlags.player_build():
		return false  # player build: developer pages off
	if "--" + PARAM in OS.get_cmdline_user_args():
		return true
	if not OS.has_feature("web"):
		return false
	if SocialWeb.dev_bench():
		return true
	var loc := JavaScriptBridge.get_interface("location")
	if loc == null:
		return false
	var where := (str(loc.search) + str(loc.hash)).to_lower()
	return where.contains(PARAM + "=1") or where.contains(PARAM + "=true")


func _init() -> void:
	layer = 30  # above everything, debug panel included


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BACKGROUND
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 30.0
	box.offset_right = -30.0
	box.offset_top = 60.0
	box.offset_bottom = -40.0
	box.add_theme_constant_override("separation", 18)
	add_child(box)
	var title := _label("CHALLENGE A FRIEND\nGENERATION TEST (DEV)", 34, 900)
	box.add_child(title)
	_out = _label("", 22, 700)
	_out.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_out.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_out)
	_again = PillButton.new("RUN AGAIN", PillButton.Icon.NONE, Color("#C645E6"), Palette.WHITE, 28)
	_again.name = "RunAgain"
	_again.custom_minimum_size = Vector2(0, 90)
	_again.pressed.connect(func(): _run())
	box.add_child(_again)
	var close := PillButton.new("CLOSE", PillButton.Icon.NONE, Palette.WHITE, Palette.TEXT, 28)
	close.custom_minimum_size = Vector2(0, 90)
	close.pressed.connect(queue_free)
	box.add_child(close)
	_run.call_deferred()


func _run() -> void:
	if _running:
		return
	_running = true
	_again.disabled = true
	results.clear()
	WebBridge.publish("chainEscapeFriendBench", {"done": false, "running": true})
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var lines := ["Each run: one slice per frame, as in the real creator.", ""]
	for d in FriendGenerator.DIFFICULTIES:
		var times := []
		var diffs := []
		var bands := 0
		var prev := ""
		for i in RUNS:
			_out.text = "\n".join(lines + ["%s: run %d / %d…" % [d.to_upper(), i + 1, RUNS]])
			await get_tree().process_frame
			# Every run after the first is a NEW CHALLENGE (previous board avoided).
			var g := FriendGenerator.new(d, rng.randi() | 1, [prev] if prev != "" else [])
			var t0 := Time.get_ticks_msec()
			while not g.step():
				await get_tree().process_frame
			var ms := Time.get_ticks_msec() - t0
			if g.puzzle == null:
				times.append(ms)
				continue
			prev = FriendGenerator.board_key(g.puzzle)
			times.append(ms)
			diffs.append(g.metrics["difficulty"])
			bands += 1 if g.metrics["in_band"] else 0
		times.sort()
		diffs.sort()
		var row := {"difficulty": d, "runs": RUNS, "ok": diffs.size(), "in_band": bands,
			"ms_median": times[times.size() / 2], "ms_max": times[-1],
			"diff_min": diffs[0] if diffs.size() else 0.0, "diff_max": diffs[-1] if diffs.size() else 0.0}
		results.append(row)
		lines.append("%s  ok %d/%d  in band %d\n   median %d ms   max %d ms   difficulty %.1f-%.1f" % [
			d.to_upper(), row["ok"], RUNS, bands, row["ms_median"], row["ms_max"], row["diff_min"], row["diff_max"]])
		_out.text = "\n".join(lines)
	_out.text = "\n".join(lines + ["", "Done."])
	WebBridge.publish("chainEscapeFriendBench", {"done": true, "results": results})
	_running = false
	_again.disabled = false


func _label(t: String, fs: int, weight: int) -> Label:
	var l := Label.new()
	l.text = t
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Palette.font(weight))
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", Palette.TEXT)
	return l
