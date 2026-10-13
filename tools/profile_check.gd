extends Node
## PLAYER IDENTITY (Phase 3A, QA) checks - headless, its own save files only:
##   godot --headless --path . res://tools/ProfileCheck.tscn
## A. Ids: random UUID v4 format, all different, validation.
## B. Names: Hebrew / Arabic / English / accents and marks accepted; spaces
##    collapsed; controls, bidi / zero-width formatting, emoji, symbols,
##    other scripts, stray or stacked marks, length limits refused.
## C. Persistence: one id per save, kept across saves / reloads; the
##    [profile] section is the ONLY change to an existing save.
## D. Corruption recovery: a damaged newest copy never changes the id (it
##    is recovered from .bak / .tmp); an invalid stored id / name is
##    replaced / cleared and noted.
## E. Merge (restore / transfer): fresh destination adopts the source
##    identity; a destination with progress keeps its own (conflicting ids
##    and names); same player - newer name wins; old saves without a
##    profile change nothing; invalid source ids are ignored.
## F. Backup code round trip and the game's own restore.
## G. Identity off (the player build): no id made, no name accepted, no
##    profile merge - and a [profile] already in a save is kept as it is.
## H. Isolation: release (r2) save names unchanged; the QA / release files
##    each get their own id.
## I. The real game: one id at start, the same after a restart; Settings
##    name accepted / refused; progress, coins, PBs untouched.

const DIR := "user://profile_check/"
var passed := 0
var failures: Array[String] = []
var _done: Array[String] = []


func _check(cond: bool, what: String) -> void:
	if cond:
		passed += 1
		if OS.get_cmdline_user_args().has("--verbose"):
			print("ok: " + what)
	else:
		failures.append(what)
		print("FAIL: " + what)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	PlayerProgress.log_enabled = false
	PlayerProgress.identity_enabled = true
	_ids()
	_names()
	_persistence()
	_corruption()
	_merge()
	_backup()
	_identity_off()
	_isolation()
	PlayerProgress.log_enabled = true
	await _game()
	_check(_done == ["ids", "names", "persistence", "corruption", "merge", "backup", "off", "isolation", "game"],
		"every section ran to its end (%s)" % [_done])
	_wipe_dir()
	print("%d checks passed, %d failed" % [passed, failures.size()])
	if failures.is_empty():
		print("PROFILE CHECKS PASSED")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("FAIL: " + f)
		get_tree().quit(1)


func _wipe_dir() -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)


func _wipe(path: String) -> void:
	for suffix in ["", ".bak", ".tmp", ".beacon"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _fresh(name: String) -> PlayerProgress:
	var path := DIR + name + ".cfg"
	_wipe(path)
	return PlayerProgress.new(path).load_from_disk()


## A save with real progress (3 levels, coins, boosters, times).
func _with_progress(p: PlayerProgress) -> PlayerProgress:
	for n in [1, 2, 3]:
		p.record_result(n, 9000 + n, 3)
		p.record_time(n, 5000 + n * 100, true)
	p.coins = 321
	p.inventory = {"hint": 2, "hammer": 1}
	return p


# --- A. Ids ----------------------------------------------------------------------

func _ids() -> void:
	var seen := {}
	var all_valid := true
	for i in 2000:
		var id := PlayerProfile.new_id()
		all_valid = all_valid and PlayerProfile.is_valid_id(id) and id.length() == 36 and id[14] == "4" and "89ab".contains(id[19])
		seen[id] = true
	_check(all_valid, "2000 new ids: UUID v4 format (version 4, RFC 4122 variant)")
	_check(seen.size() == 2000, "2000 new ids: all different")
	for bad in ["", "abc", "00000000-0000-0000-0000-000000000000", "6F9619FF-8B86-4D01-B42D-00CF4FC964FF", "6f9619ff-8b86-1d01-b42d-00cf4fc964ff",
			"6f9619ff-8b86-4d01-742d-00cf4fc964ff", " 6f9619ff-8b86-4d01-b42d-00cf4fc964ff", "6f9619ff8b864d01b42d00cf4fc964ff"]:
		_check(not PlayerProfile.is_valid_id(bad), "not a valid id: '%s'" % bad)
	_check(PlayerProfile.is_valid_id("6f9619ff-8b86-4d01-b42d-00cf4fc964ff"), "a lower-case v4 UUID is valid")
	_done.append("ids")


# --- B. Names --------------------------------------------------------------------

func _names() -> void:
	var ok_cases := {
		"Dana": "Dana", "  Dana   Cohen  ": "Dana Cohen", "O'Neil": "O'Neil", "Jean-Luc": "Jean-Luc", "a.b_c": "a.b_c",
		"José": "José", "Zoë": "Zoë", "Łukasz": "Łukasz", "José": "José",
		"דנה": "דנה", "דנה כהן": "דנה כהן", "שָׁלוֹם": "שָׁלוֹם", "בן־חיים": "בן־חיים", "ז״ל": "ז״ל",
		"محمد": "محمد", "مُحَمَّد": "مُحَمَّد", "ليلى ٢٣": "ليلى ٢٣", "Dana דנה": "Dana דנה", "R2D2": "R2D2", "123": "123",
		"": "", "   ": "",
		# Phase 3A polish: mixed scripts, more scripts the fonts draw, iPhone apostrophe.
		"Loay לואי": "Loay לואי", "Loay محمد": "Loay محمد", "לואי Alex": "לואי Alex", "Loay لؤي לואי": "Loay لؤي לואי",
		"Loay 23 לואי": "Loay 23 לואי", "לואי-Alex": "לואי-Alex", "Дана": "Дана", "Ελένη": "Ελένη", "Nguyễn Văn Ánh": "Nguyễn Văn Ánh",
		"Ștefan": "Ștefan", "Ŵyn": "Ŵyn", "O’Neil": "O'Neil", "O‘Neil": "O'Neil", "Alexandra Konstantin": "Alexandra Konstantin",
		"עמנואל בן אברהם כהן": "עמנואל בן אברהם כהן",
	}
	for raw in ok_cases:
		var r := PlayerProfile.clean_name(raw)
		_check(r["ok"] and r["name"] == ok_cases[raw], "name accepted: '%s' -> '%s' (%s)" % [raw, ok_cases[raw], r])
	var bad_cases := {
		"D": "too_short", "ABCDEFGHIJKLMNOPQRSTU": "too_long", "דנהדנהדנהדנהדנהדנהדנה": "too_long", "Alexandra Konstantine": "too_long",
		"Dana\U01F600": "unsupported", "Dana\u202E": "unsupported", "\u202Edana": "unsupported", "Da\u200Bna": "unsupported",
		"Da\u200Dna": "unsupported", "\u2066Dana\u2069": "unsupported", "\u200FDana": "unsupported", "\u061CDana": "unsupported",
		"Da\nna": "unsupported", "Da\tna": "unsupported", "Da\u0001na": "unsupported", "Da\u007Fna": "unsupported", "Da\uFFFDna": "unsupported", "Da\u00A0na": "unsupported",
		"<b>Dana": "unsupported", "Dana!": "unsupported", "Da\"na": "unsupported", "Da\\na": "unsupported", "Dana#1": "unsupported",
		"王芳": "unsupported", "Dana\uFE0F": "unsupported", "\u0600Dana": "unsupported",
		"\u01C5ana": "unsupported", "Да\u0483на": "unsupported", "Ab\u037E": "unsupported", "Ab\u03D1": "unsupported", "\u0531bc": "unsupported",
		"Loay \U01F3C6": "unsupported", "Loay \u2764\uFE0F": "unsupported", "Loay \U01F525": "unsupported", "Loay \u2B50": "unsupported", "Loay \U01F9E9": "unsupported",
		"Lo\u200Day": "unsupported", "Loay\u2019\u202E": "unsupported",
		"́ab": "mark", "á́́́b": "mark", "Dana ́x": "mark",
		"---": "no_letters", "..": "no_letters", "'_'": "no_letters",
	}
	for raw in bad_cases:
		var r := PlayerProfile.clean_name(raw)
		_check(not r["ok"] and r["error"] == bad_cases[raw], "name refused (%s): %s -> %s" % [bad_cases[raw], _codes(raw), r])
	_check(PlayerProfile.NAME_MAX == 20 and PlayerProfile.clean_name("ABCDEFGHIJKLMNOPQRST")["ok"] and PlayerProfile.clean_name("Di")["ok"], "20 and 2 characters are the limits")
	# Length = user-perceived characters: a letter with its marks counts once.
	_check(PlayerProfile.grapheme_count("שָׁלוֹם") == 4 and PlayerProfile.grapheme_count("مُحَمَّد") == 4 and PlayerProfile.grapheme_count("Loay لؤي לואי") == 13, "length counts grapheme clusters")
	var pointed := ""
	for i in 20:
		pointed += "שָׁ"  # shin + qamats + shin dot: 3 code points, 1 character
	_check(pointed.length() == 60 and PlayerProfile.clean_name(pointed)["ok"] and PlayerProfile.clean_name(pointed)["name"] == pointed, "20 pointed Hebrew letters (60 code points) fit, unsplit")
	_check(PlayerProfile.clean_name(pointed + "ש")["error"] == "too_long", "... a 21st letter does not")
	_check(PlayerProfile.error_text("too_long").contains("20") and PlayerProfile.error_text("unsupported") != "", "every error has a friendly text")
	_fonts()
	_done.append("names")


## Every code point a name may hold must be drawable on the Web build: the
## engine's built-in Open Sans (ThemeDB.fallback_font - the Web has no
## system fonts) or the bundled Noto Hebrew / Arabic fallbacks.
func _fonts() -> void:
	var fonts: Array[Font] = [ThemeDB.fallback_font]
	for path in MessageText.FALLBACKS:
		fonts.append(load(path))
	var allowed := 0
	var missing := PackedStringArray()
	for c in range(0x20, 0x30000):
		if not (PlayerProfile.is_base(c) or PlayerProfile.is_mark(c)):
			continue
		allowed += 1
		var drawn := false
		for f in fonts:
			if f.has_char(c):
				drawn = true
				break
		if not drawn:
			missing.append("U+%04X" % c)
	_check(missing.is_empty() and allowed > 900, "every allowed name character (%d) has a glyph in the Web fonts (missing: %s)" % [allowed, " ".join(missing.slice(0, 20))])


static func _codes(t: String) -> String:
	var out := PackedStringArray()
	for i in t.length():
		var c := t.unicode_at(i)
		out.append(char(c) if c >= 0x20 and c < 0x7F else "U+%04X" % c)
	return "".join(out)


# --- C. Persistence ---------------------------------------------------------------

func _persistence() -> void:
	var p := _with_progress(_fresh("persist"))
	p.save()
	var before := FileAccess.get_file_as_string(p.path)
	_check(not before.contains("[profile]") and p.player_id == "", "a save is made without a profile until identity is ensured")
	_check(p.ensure_identity() and PlayerProfile.is_valid_id(p.player_id) and p.profile_created_unix > 0, "ensure_identity creates a valid id")
	var id := p.player_id
	_check(not p.ensure_identity() and p.player_id == id, "a second ensure_identity changes nothing")
	p.save()
	var after := FileAccess.get_file_as_string(p.path)
	_check(after.contains("[profile]") and after.contains(id), "the id is saved in [profile]")
	_check(_sections_equal(before, after, ["profile", "meta"]), "nothing else in the save changed (all sections but [profile] / [meta] identical)")
	var q := PlayerProgress.new(p.path).load_from_disk()
	_check(q.player_id == id and not q.ensure_identity(), "reloaded: the same id, nothing to repair")
	_check(q.best_scores == p.best_scores and q.coins == 321 and q.inventory["hint"] == 2 and q.best_time(2) == 5200 and q.best_clean_time(3) == 5300,
		"reloaded: scores, coins, boosters and PB times intact")
	var r := q.set_display_name("  דנה   כהן ")
	q.save()
	var z := PlayerProgress.new(p.path).load_from_disk()
	_check(r["ok"] and z.display_name == "דנה כהן" and z.name_set_unix > 0 and z.player_id == id, "a name is saved (cleaned) and reloaded with the same id")
	for i in 5:
		z.save()
	var w := PlayerProgress.new(p.path).load_from_disk()
	_check(w.player_id == id and w.display_name == "דנה כהן", "many saves later: same id and name")
	var bad := w.set_display_name("Dana\U01F600")
	_check(not bad["ok"] and w.display_name == "דנה כהן", "an invalid name keeps the current one")
	var cleared := w.set_display_name("")
	_check(cleared["ok"] and w.display_name == "" and w.player_id == id, "an empty name removes it (the id stays)")
	_done.append("persistence")


## True if both save texts have the same sections / values, ignoring `skip`.
func _sections_equal(a: String, b: String, skip: Array) -> bool:
	var ca := ConfigFile.new()
	var cb := ConfigFile.new()
	if ca.parse(a) != OK or cb.parse(b) != OK:
		return false
	var sa := Array(ca.get_sections()).filter(func(x): return not skip.has(x))
	var sb := Array(cb.get_sections()).filter(func(x): return not skip.has(x))
	sa.sort()
	sb.sort()
	if sa != sb:
		return false
	for sec in sa:
		var ka := Array(ca.get_section_keys(sec))
		var kb := Array(cb.get_section_keys(sec))
		ka.sort()
		kb.sort()
		if ka != kb:
			return false
		for k in ka:
			if var_to_str(ca.get_value(sec, k)) != var_to_str(cb.get_value(sec, k)):
				return false
	return true


# --- D. Corruption recovery ----------------------------------------------------------

func _corruption() -> void:
	# The newest file loses its [profile] (damaged at the end); the backup still has it.
	var p := _with_progress(_fresh("corrupt"))
	p.ensure_identity()
	p.set_display_name("Avi")
	var id := p.player_id
	p.save()
	p.save()  # main = newest, .bak = the previous (both with the profile)
	var text := FileAccess.get_file_as_string(p.path)
	var cut := text.substr(0, text.find("[profile]"))
	var f := FileAccess.open(p.path, FileAccess.WRITE)
	f.store_string(cut + "\n[meta]\n\nseq=99\n")  # newest, readable, no profile
	f.close()
	var q := PlayerProgress.new(p.path).load_from_disk()
	_check(q.player_id == "", "the newest copy (seq 99) has no profile")
	_check(q.ensure_identity() and q.player_id == id and q.display_name == "Avi" and q.load_issues.any(func(x): return String(x).contains("recovered")),
		"the id and name are recovered from the backup copy, not replaced (%s)" % ", ".join(q.load_issues))
	# Garbage main file: the backup is loaded with its profile.
	var g := FileAccess.open(p.path, FileAccess.WRITE)
	g.store_string("\u0000\u0001 not a save {{{[[[")
	g.close()
	var r := PlayerProgress.new(p.path).load_from_disk()
	r.ensure_identity()
	_check(r.player_id == id, "an unreadable main file: the backup's id is kept")
	# Invalid stored id / name.
	var t := _fresh("invalid")
	t.save()
	var txt := FileAccess.get_file_as_string(t.path) + "\n[profile]\n\nid=\"not-a-uuid\"\nname=\"Dana\u202E\"\nname_set_unix=5\ncreated_unix=5\n"
	var h := FileAccess.open(t.path, FileAccess.WRITE)
	h.store_string(txt)
	h.close()
	var u := PlayerProgress.new(t.path).load_from_disk()
	_check(u.player_id == "not-a-uuid", "an invalid id is read as stored")
	_check(u.ensure_identity() and PlayerProfile.is_valid_id(u.player_id) and u.display_name == "",
		"an invalid stored id is replaced and an invalid name cleared (%s)" % ", ".join(u.load_issues))
	_check(u.load_issues.any(func(x): return String(x).contains("id not valid")) and u.load_issues.any(func(x): return String(x).contains("name not valid")),
		"both repairs are noted in the load issues")
	# Nothing readable at all: a new id (the save itself is new).
	var n := _fresh("empty")
	_check(n.ensure_identity() and PlayerProfile.is_valid_id(n.player_id), "no save at all: a new id")
	_done.append("corruption")


# --- E. Merge -------------------------------------------------------------------------

func _source(name: String, nm: String, t: int, progress := true) -> PlayerProgress:
	var s := _fresh(name)
	if progress:
		_with_progress(s)
	s.ensure_identity()
	s.display_name = nm
	s.name_set_unix = t
	return s


func _merge() -> void:
	# 1. Fresh destination (no progress, its own new id) adopts the source.
	var src := _source("m_src", "Dana", 100)
	var dst := _fresh("m_dst")
	dst.ensure_identity()
	var r := dst.merge_from(src)
	_check(r["profile"] == "adopted" and dst.player_id == src.player_id and dst.display_name == "Dana" and dst.best_scores.size() == 3,
		"a new device restoring a backup takes that player's id and name (and the progress)")
	# 1b. Destination with no id at all.
	var dst0 := _fresh("m_dst0")
	_check(dst0.merge_from(src)["profile"] == "adopted" and dst0.player_id == src.player_id, "a save with no id yet adopts the source id")
	# 2. Destination with progress: keeps its own id AND name; progress still merged.
	var mine := _source("m_mine", "Avi", 500)
	mine.best_scores[4] = 7000
	var my_id := mine.player_id
	var other := _source("m_other", "Dana", 900)
	other.best_scores[5] = 8000
	r = mine.merge_from(other)
	_check(r["profile"] == "kept_local" and mine.player_id == my_id and mine.display_name == "Avi", "conflicting ids: a save with progress keeps its own id and name")
	_check(mine.best_scores.has(4) and mine.best_scores.has(5), "conflicting ids: progress is still merged as before")
	# 2b. Destination with progress but no name, other player's name newer: still not taken.
	var mine2 := _source("m_mine2", "", 0)
	r = mine2.merge_from(_source("m_other2", "Dana", 999))
	_check(r["profile"] == "kept_local" and mine2.display_name == "", "another player's name is never copied onto this player")
	# 3. Same player: the newer name wins either way.
	var a := _source("m_a", "Avi", 100)
	var b := _source("m_b", "Avraham", 200)
	b.player_id = a.player_id
	r = a.merge_from(b)
	_check(r["profile"] == "same_name_updated" and a.display_name == "Avraham", "same id: the newer name wins")
	var c := _source("m_c", "Old", 50)
	c.player_id = a.player_id
	r = a.merge_from(c)
	_check(r["profile"] == "same" and a.display_name == "Avraham", "same id: an older name does not overwrite")
	var d := _source("m_d", "", 300)
	d.player_id = a.player_id
	a.merge_from(d)
	_check(a.display_name == "", "same id: a newer removal of the name is kept")
	# 4. Source without a profile (a backup from before 3A): nothing changes.
	var oldsrc := _with_progress(_fresh("m_old"))
	var e := _source("m_e", "Avi", 10, false)
	var e_id := e.player_id
	r = e.merge_from(oldsrc)
	_check(r["profile"] == "none" and e.player_id == e_id and e.display_name == "Avi" and e.best_scores.size() == 3,
		"an old backup without a profile: the id and name stay, progress is merged")
	# 5. Invalid source id / name.
	var badsrc := _source("m_bad", "Dana", 100)
	badsrc.player_id = "nope"
	var f := _fresh("m_f")
	f.ensure_identity()
	var f_id := f.player_id
	_check(f.merge_from(badsrc)["profile"] == "none" and f.player_id == f_id, "an invalid source id is ignored")
	var badname := _source("m_badname", "Dana\u202E", 100)
	var g := _fresh("m_g")
	g.ensure_identity()
	g.merge_from(badname)
	_check(g.player_id == badname.player_id and g.display_name == "", "an adopted invalid name is dropped (the id is taken)")
	_done.append("merge")


# --- F. Backup code ---------------------------------------------------------------------

func _backup() -> void:
	var p := _source("b_src", "مُحَمَّد", 123)
	var code := p.backup_code()
	var q := PlayerProgress.from_text(PlayerProgress.decode_backup(code))
	_check(q != null and q.player_id == p.player_id and q.display_name == "مُحَمَّد" and q.name_set_unix == 123,
		"a backup code carries the id and the (Arabic) name")
	var fresh := _fresh("b_dst")
	fresh.ensure_identity()
	fresh.merge_from(q)
	fresh.save()
	var back := PlayerProgress.new(fresh.path).load_from_disk()
	_check(back.player_id == p.player_id and back.display_name == "مُحَمَّد" and back.best_scores.size() == 3, "restored on a new device, saved and reloaded: same player")
	_check(not code.contains(p.player_id), "the id is not readable in the code text (compressed, not a separate token)")
	_done.append("backup")


# --- G. Identity off (the player build) --------------------------------------------------

func _identity_off() -> void:
	var p := _source("off_src", "Dana", 100)
	p.save()
	var id := p.player_id
	PlayerProgress.identity_enabled = false
	var q := PlayerProgress.new(p.path).load_from_disk()
	_check(not q.ensure_identity() and q.player_id == id, "identity off: nothing is created or repaired")
	_check(not q.set_display_name("Avi")["ok"] and q.display_name == "Dana", "identity off: no name accepted")
	q.record_result(9, 1234, 2)
	q.save()
	var txt := FileAccess.get_file_as_string(q.path)
	_check(txt.contains("[profile]") and txt.contains(id) and txt.contains("\"Dana\""), "identity off: a profile already in the save is written back unchanged")
	var none := _with_progress(_fresh("off_none"))
	_check(not none.ensure_identity() and none.player_id == "", "identity off: a save without a profile gets none")
	none.save()
	_check(not FileAccess.get_file_as_string(none.path).contains("[profile]"), "identity off: no [profile] section is written")
	var fresh := _fresh("off_fresh")
	_check(fresh.merge_from(p)["profile"] == "off" and fresh.player_id == "", "identity off: a restore never takes a profile")
	PlayerProgress.identity_enabled = true
	_done.append("off")


# --- H. Isolation -------------------------------------------------------------------------

func _isolation() -> void:
	_check(PlayerProgress.RELEASE_SAVE_PATH == "user://progress_r2.cfg" and PlayerProgress.RELEASE_MIRROR_KEY == "chain_escape_save_r2"
		and PlayerProgress.RELEASE_BEACON_KEY == "chain_escape_beacon_r2", "release (r2) save names unchanged")
	_check(ExperienceLab.QA_SAVE_PATH != PlayerProgress.RELEASE_SAVE_PATH and ExperienceLab.QA_MIRROR_KEY != PlayerProgress.RELEASE_MIRROR_KEY,
		"the QA save is a different file and key")
	var a := _fresh("iso_release")
	var b := _fresh("iso_qa")
	a.ensure_identity()
	b.ensure_identity()
	_check(a.player_id != b.player_id, "two saves (e.g. release and QA) have different ids")
	_done.append("isolation")


# --- I. The real game -----------------------------------------------------------------------

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _game() -> void:
	var save_path := DIR + "game.cfg"
	_wipe(save_path)
	PlayerProgress.default_path = save_path
	var game = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game)
	await _frames(6)
	AudioManager.set_music_enabled(false)
	var id: String = game.progress.player_id
	_check(PlayerProgress.identity_enabled and PlayerProfile.is_valid_id(id), "the game makes an id at its first start")
	_check(FileAccess.get_file_as_string(save_path).contains(id), "... and saves it at once")
	_check(game.ui._name_button != null and game.ui.name_row_state()["text"] == "ADD YOUR NAME (OPTIONAL)", "Settings has the optional name row")
	game.ui._open_settings()
	await _frames(2)
	game.set_display_name("דנה")
	_check(game.progress.display_name == "דנה" and game.ui.name_row_state()["text"].contains("דנה") and game.ui.name_row_state()["note"] == "Name saved",
		"a Hebrew name from Settings is saved and shown ('%s')" % game.ui.name_row_state()["text"])
	# Phase 3A polish: the Settings modal draws, and takes taps, above the HUD.
	var ls: Dictionary = game.ui.settings_layer_state()
	_check(ls["open"] and ls["over"].is_empty(), "Settings is above every HUD control (drawing over it: %s)" % [ls["over"]])
	game.set_display_name("WWWWWWWWWW WWWWWWWWW")
	await _frames(2)
	var st: Dictionary = game.ui.name_row_state()
	_check(game.progress.display_name == "WWWWWWWWWW WWWWWWWWW" and st["font_size"] >= 19 and st["font_size"] < 26,
		"a wide 20-character name is saved whole; the row font steps down (%d)" % st["font_size"])
	_check(st["rect"][0] >= st["card"][0] and st["rect"][2] <= st["card"][2] and st["card"][0] >= 0.0 and st["card"][2] <= 1.0,
		"... and the row stays inside the card, the card inside the screen (%s / %s)" % [st["rect"], st["card"]])
	game.set_display_name("Loay لؤي לואי")
	await _frames(2)
	_check(game.progress.display_name == "Loay لؤي לואי" and game.ui.name_row_state()["font_size"] == 26, "a mixed-script name is saved; normal font again")
	game.set_display_name("דנה")
	game.set_display_name("x")
	_check(game.progress.display_name == "דנה" and game.ui.name_row_state()["note"] == PlayerProfile.error_text("too_short"), "a refused name keeps the old one and says why")
	game.ui._close_settings()
	game._hide_title()
	game.start_level(1, "select")
	await _frames(2)
	# A tap on the coin counter while Settings is open reaches the dimmer
	# (closes Settings), never the coin pill under it (the shop).
	game.ui._open_settings()
	await _frames(2)
	_check(game.ui.settings_layer_state()["over"].is_empty(), "in a level: Settings still above the HUD")
	var at: Vector2 = game.ui._coin_pill.get_global_rect().get_center()
	var outside: bool = not game.ui._settings_card.get_global_rect().has_point(at)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		get_viewport().push_input(ev, true)
		await _frames(1)
	await _frames(2)
	_check(not game.ui.is_shop_open() and (not outside or not game.ui.is_settings_open()),
		"a tap on the coins with Settings open does not open the shop (shop %s, settings %s)" % [game.ui.is_shop_open(), game.ui.is_settings_open()])
	game.ui._close_settings()
	await _frames(1)
	var coins: int = game.progress.coins
	var scores: Dictionary = game.progress.best_scores.duplicate()
	game.queue_free()
	await _frames(3)
	var game2 = load("res://scenes/Main.tscn").instantiate()
	get_tree().root.add_child(game2)
	await _frames(6)
	_check(game2.progress.player_id == id and game2.progress.display_name == "דנה", "restarting the game: the same id and name")
	_check(game2.progress.coins == coins and game2.progress.best_scores == scores, "restarting the game: coins and scores unchanged")
	_check(game2.ui.name_row_state()["text"].contains("דנה"), "the name row shows the saved name after a restart")
	# The game's own restore: this save has no progress -> adopts the code's player.
	var src := _source("g_src", "Dana", 100)
	game2.apply_restore(src.backup_code())
	await _frames(2)
	_check(game2.progress.player_id == src.player_id and game2.progress.display_name == "Dana" and game2.progress.best_scores.size() >= 3,
		"RESTORE on a save without progress: that player's id, name and progress")
	# Now this save has progress: another player's code keeps this identity.
	var other := _source("g_other", "Avi", 999)
	game2.apply_restore(other.backup_code())
	await _frames(2)
	_check(game2.progress.player_id == src.player_id and game2.progress.display_name == "Dana", "RESTORE of another player's code on a save with progress: identity kept")
	game2.queue_free()
	await _frames(3)
	_wipe(save_path)
	_done.append("game")
