class_name ShopPanel
extends ColorRect
## Booster shop (Coins only - no real money). Two items in v0.4: Hint and
## Hammer. Prices come from data/economy.json.

signal buy_requested(item: String)
signal closed

var _balance: Label
var _rows: Dictionary = {}  # item -> {"owned": Label, "buy": PillButton}
var _note: Label

const ITEMS := {
	"hint": {"title": "SHOW A MOVE", "desc": "Shows one good move", "icon": PillButton.Icon.HINT},
	"hammer": {"title": "HAMMER", "desc": "Smash one block (only if the level stays solvable)", "icon": PillButton.Icon.HAMMER},
}


func _init() -> void:
	color = Color(Palette.TEXT, 0.45)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var card := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Palette.WHITE
	st.set_corner_radius_all(40)
	st.set_content_margin_all(36)
	st.anti_aliasing = true
	card.add_theme_stylebox_override("panel", st)
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	card.add_child(box)
	box.add_child(_label("SHOP", 44, Palette.TEXT))
	_balance = _label("", 30, Palette.TEXT)
	box.add_child(_balance)
	for item in ITEMS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		box.add_child(row)
		var icon := PillButton.new("", ITEMS[item]["icon"], Palette.BACKGROUND, Palette.TEXT, 24)
		icon.custom_minimum_size = Vector2(84, 84)
		icon.disabled = false
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(info)
		var t := _label(ITEMS[item]["title"], 28, Palette.TEXT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.add_child(t)
		var d := _label(ITEMS[item]["desc"], 18, Palette.TEXT_SOFT)
		d.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(250, 0)
		info.add_child(d)
		var owned := _label("", 20, Palette.ACCENT)
		owned.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		info.add_child(owned)
		var buy := PillButton.new("", PillButton.Icon.COIN, Palette.ACCENT, Palette.WHITE, 26, true)
		buy.custom_minimum_size = Vector2(150, 80)
		buy.pressed.connect(func(): buy_requested.emit(item))
		row.add_child(buy)
		_rows[item] = {"owned": owned, "buy": buy}
	_note = _label("Earn Coins by clearing levels, earning stars, PERFECT clears and treasure chests.", 18, Palette.TEXT_SOFT)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_note.custom_minimum_size = Vector2(540, 0)
	box.add_child(_note)
	var done := PillButton.new("CLOSE", PillButton.Icon.NONE, Palette.BACKGROUND, Palette.TEXT, 28)
	done.custom_minimum_size = Vector2(0, 84)
	done.pressed.connect(close)
	box.add_child(done)


func open(coins: int, inventory: Dictionary) -> void:
	refresh(coins, inventory)
	visible = true


func refresh(coins: int, inventory: Dictionary) -> void:
	if _balance == null:
		return
	_balance.text = "%d COINS" % coins
	for item in _rows:
		var price := Economy.price(item)
		_rows[item]["owned"].text = "Owned: %d" % inventory.get(item, 0)
		_rows[item]["buy"].text = str(price)
		_rows[item]["buy"].disabled = coins < price


func close() -> void:
	visible = false
	closed.emit()


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", Palette.font(900))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l
