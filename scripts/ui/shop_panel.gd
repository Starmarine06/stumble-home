class_name ShopPanel
extends Control
## One corner shop's counter: what is on sale, what it costs, and the crew's pool to pay from.

signal closed

var shop := ""
var _money := Label.new()
var _rows: Array = []     # [{item, label, button}]


func _init(p_shop: String = "pharmacy") -> void:
	shop = p_shop
	var cat: Dictionary = ShopItems.CATALOG.get(shop, {})
	var items: Array = ShopItems.items_of(shop)
	custom_minimum_size = Vector2(560, 150 + 62 * items.size())
	size = custom_minimum_size
	var bg := PanelContainer.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.06, 0.09, 0.94)
	sb.border_color = Color(0.4, 0.8, 0.95, 0.95)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.set_content_margin_all(14)
	bg.add_theme_stylebox_override("panel", sb)
	add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	bg.add_child(col)
	var title := Label.new()
	title.text = cat.get("title", shop.to_upper())
	title.add_theme_font_size_override("font_size", 22)
	col.add_child(title)
	var blurb := Label.new()
	blurb.text = cat.get("blurb", "")
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
	col.add_child(blurb)
	col.add_child(_money)
	for it in items:
		var row := HBoxContainer.new()
		var l := Label.new()
		l.custom_minimum_size = Vector2(400, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(l)
		var b := Button.new()
		b.custom_minimum_size = Vector2(110, 0)
		b.pressed.connect(Game.request_buy_item.bind(shop, it.id))
		row.add_child(b)
		col.add_child(row)
		_rows.append({"item": it, "label": l, "button": b})
	var close := Button.new()
	close.text = "Leave"
	close.pressed.connect(func(): closed.emit())
	col.add_child(close)
	refresh()
	Game.money_changed.connect(refresh)
	Game.item_bought.connect(_on_bought)


func _exit_tree() -> void:
	if Game.money_changed.is_connected(refresh):
		Game.money_changed.disconnect(refresh)
	if Game.item_bought.is_connected(_on_bought):
		Game.item_bought.disconnect(_on_bought)


func _on_bought(_peer: int, _shop: String, _id: String) -> void:
	refresh()


func refresh() -> void:
	_money.text = "Crew pool: $%d" % Game.money
	for r in _rows:
		var it: Dictionary = r.item
		var price := int(it.price)
		var taken: bool = it.get("once", false) and Game.bought.has("%s/%s" % [shop, it.id])
		var gain := price < 0
		r.label.text = "%s   %s\n%s" % [it.name, ("+$%d" % -price) if gain else ("$%d" % price), it.blurb]
		var b: Button = r.button
		b.text = "Done" if taken else ("Sell" if gain else "Buy")
		b.disabled = taken or (not gain and Game.money < price)
