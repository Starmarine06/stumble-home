class_name CityBuildings
extends RefCounted
## The building styles of the city: family houses, villas with a pool, apartment blocks, office
## towers and mixed-use shops, plus the reserved landmark and home buildings. Everything is boxes,
## but each style has the shapes you expect: gabled roofs and chimneys, flat roofs with plant on top,
## windows that light up at night, balconies, entrances, gardens. The block builder asks for a style
## per lot and this draws it, with the front on the setback line so doors line up with the pavement.

const FLOOR_H := 3.2
const WINDOW_TILE := 12.8     # one repeat of the window texture: 4 windows wide, 4 floors high
const HOUSE_COLORS := [Color(0.82, 0.62, 0.5), Color(0.62, 0.7, 0.78), Color(0.78, 0.74, 0.55), Color(0.7, 0.55, 0.6), Color(0.6, 0.72, 0.58), Color(0.85, 0.8, 0.72)]
const BRICK_COLORS := [Color(0.62, 0.32, 0.25), Color(0.55, 0.3, 0.22), Color(0.7, 0.45, 0.35), Color(0.5, 0.38, 0.32)]
const CONCRETE_COLORS := [Color(0.62, 0.62, 0.6), Color(0.72, 0.7, 0.66), Color(0.55, 0.58, 0.62), Color(0.8, 0.76, 0.68)]
const VILLA_COLORS := [Color(0.95, 0.93, 0.88), Color(0.96, 0.9, 0.8), Color(0.88, 0.92, 0.95)]
const ROOF_COLORS := [Color(0.35, 0.18, 0.15), Color(0.22, 0.25, 0.32), Color(0.3, 0.3, 0.26)]
const SHOP_COLORS := [Color(0.55, 0.3, 0.3), Color(0.3, 0.45, 0.55), Color(0.5, 0.5, 0.3), Color(0.4, 0.3, 0.5), Color(0.3, 0.5, 0.4)]
const SHOP_NAMES := ["LAUNDRETTE", "NOODLES", "VIDEO", "BAKERY", "HAIR", "BOOKS", "PHONES", "FLORIST", "CAFE", "TAILOR", "VAPES", "CHIPPY"]
const OFFICE_NAMES := ["ACME CORP", "SYNERGY LTD", "LEGAL & GENERAL ADVICE", "HOLDINGS", "TELECOM", "INSURANCE", "BANK"]
const SPECIAL_COLORS := {
	"delivery": Color(0.95, 0.55, 0.1), "garage": Color(0.4, 0.45, 0.5), "pharmacy": Color(0.2, 0.7, 0.45),
	"pawn": Color(0.65, 0.5, 0.2), "pub": Color(0.5, 0.2, 0.15), "kebab": Color(0.9, 0.35, 0.15),
}
const SPECIAL_LABELS := {
	"delivery": "SKETCHY DELIVERIES", "garage": "GARAGE", "pharmacy": "PHARMACY",
	"pawn": "PAWN SHOP", "pub": "THE WOBBLY PUB", "kebab": "KEBABS",
}
const DOOR_GAP := 1.8
const WALL := 0.4

var b: CityBuilder
var _win_tex: ImageTexture
var _lit_tex: Array[ImageTexture] = []
var _facades: Dictionary = {}


func _init(builder: CityBuilder) -> void:
	b = builder
	_make_textures()


## The style of a lot, stable from its id: what kind of building stands on it.
static func style_of(lot: Dictionary) -> String:
	match lot.kind:
		"special":
			return "special"
		"home":
			return "home"
		"park":
			return "park"
	var h := (int(lot.id) * 7) % 10
	if lot.kind == "shop":
		return "shop" if h < 5 else ("office" if h < 7 else "apartment")
	return "house" if h < 5 else ("villa" if h < 7 else "apartment")


## One family house in four is hollow, with a doorway you can walk through.
static func is_open_house(lot: Dictionary) -> bool:
	return style_of(lot) == "house" and int(lot.id) % 4 == 1


# --- Window texture ----------------------------------------------------------------------------

## 4 x 4 windows per tile: dark glass in the albedo, and lit ones (a few densities) in the emission.
func _make_textures() -> void:
	var albedo := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	albedo.fill(Color.WHITE)
	for ix in 4:
		for iy in 4:
			albedo.fill_rect(Rect2i(ix * 16 + 2, iy * 16 + 3, 12, 10), Color(0.78, 0.78, 0.76))     # frame
			albedo.fill_rect(Rect2i(ix * 16 + 1, iy * 16 + 13, 14, 2), Color(0.62, 0.62, 0.6))      # sill
			albedo.fill_rect(Rect2i(ix * 16 + 3, iy * 16 + 4, 10, 8), Color(0.16, 0.22, 0.32))      # glass
			albedo.fill_rect(Rect2i(ix * 16 + 7, iy * 16 + 4, 2, 8), Color(0.78, 0.78, 0.76))       # mullion
	_win_tex = ImageTexture.create_from_image(albedo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for density in [0.3, 0.5, 0.7]:
		var em := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		em.fill(Color.BLACK)
		for ix in 4:
			for iy in 4:
				if rng.randf() < density:
					em.fill_rect(Rect2i(ix * 16 + 3, iy * 16 + 4, 10, 8), Color(1.0, rng.randf_range(0.7, 0.9), rng.randf_range(0.4, 0.6)))
		_lit_tex.append(ImageTexture.create_from_image(em))


## Wall material with windows tiled to the building's real size, so floors and windows stay square.
func facade(c: Color, w: float, h: float, glow := 1.4, seed_value := 0) -> StandardMaterial3D:
	var cols := maxi(1, int(round(w / WINDOW_TILE * 2.0)))
	var rows := maxi(1, int(round(h / WINDOW_TILE * 2.0)))
	var variant := absi(seed_value) % _lit_tex.size()
	var key := "%s_%d_%d_%d_%s" % [c.to_html(), cols, rows, variant, glow]
	if _facades.has(key):
		return _facades[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = _win_tex
	m.uv1_scale = Vector3(float(cols) / 2.0, float(rows) / 2.0, 1.0)
	m.roughness = 0.85
	m.emission_enabled = true
	m.emission_texture = _lit_tex[variant]
	m.emission_energy_multiplier = glow
	_facades[key] = m
	return m


# --- Shared bits ------------------------------------------------------------------------------

func _center(ctx: Dictionary, d: float) -> Vector3:
	return ctx.perp + ctx.f * (CityLayout.BLOCK * 0.5 - CityLayout.SETBACK - d * 0.5)


## A box size from a length along the street (a) and one along the way the building faces (depth).
func _oriented(ctx: Dictionary, a: float, y: float, depth: float) -> Vector3:
	return Vector3(a, y, depth) if absf(ctx.f.z) > 0.5 else Vector3(depth, y, a)


func _front(ctx: Dictionary, pos: Vector3, d: float) -> Vector3:
	return pos + ctx.f * (d * 0.5 + 0.05) + Vector3(0, CityBuilder.CURB, 0)


func _at(ctx: Dictionary, pos: Vector3, along: float, out: float, y: float) -> Vector3:
	return pos + ctx.across * along + ctx.f * out + Vector3(0, CityBuilder.CURB + y, 0)


func _door(ctx: Dictionary, pos: Vector3, d: float, c: Color, w := 1.4, h := 2.3) -> void:
	b.box(ctx.root, _oriented(ctx, w, h, 0.2), _front(ctx, pos, d) + Vector3(0, h * 0.5, 0), c)


func _number(ctx: Dictionary, pos: Vector3, d: float, y := 2.9) -> void:
	var num := Label3D.new()
	num.text = str(ctx.lot.number)
	num.font_size = 64
	num.pixel_size = 0.012
	num.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	num.outline_size = 8
	num.position = _front(ctx, pos, d) + Vector3(0, y, 0) + ctx.f * 0.4
	ctx.root.add_child(num)


func _sign(ctx: Dictionary, pos: Vector3, d: float, text: String, y: float, col: Color, size := 96) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.02
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = col
	l.outline_size = 12
	l.position = pos + Vector3(0, CityBuilder.CURB + y, 0) + ctx.f * (d * 0.5)
	ctx.root.add_child(l)


func _roof_prism(ctx: Dictionary, pos: Vector3, w: float, d: float, h: float, c: Color) -> void:
	var roof := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(d, 2.8, w)
	pm.left_to_right = 0.5
	roof.mesh = pm
	roof.material_override = b.mat(c)
	roof.position = pos + Vector3(0, CityBuilder.CURB + h + 1.4, 0)
	if absf(ctx.f.z) > 0.5:
		roof.rotation_degrees.y = 90.0
	ctx.root.add_child(roof)


# --- Styles -----------------------------------------------------------------------------------

## A family house: two floors, gabled roof, chimney, porch, and an attached garage.
func house(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var w := 16.0
	var d := 18.0
	var h := FLOOR_H * 2.0
	var col: Color = HOUSE_COLORS[rng.randi() % HOUSE_COLORS.size()] if rng.randf() < 0.65 else BRICK_COLORS[rng.randi() % BRICK_COLORS.size()]
	var pos := _center(ctx, d)
	var open := is_open_house(ctx.lot)
	if open:
		_open_house(ctx, pos, w, d, h, col)
	else:
		b.solid_box_mat(ctx.root, _oriented(ctx, w, h, d), _at(ctx, pos, 0, 0, h * 0.5), facade(col, w, h, 1.3, int(ctx.lot.id)))
		_door(ctx, pos, d, Color(0.25, 0.15, 0.1))
	_roof_prism(ctx, pos, w, d, h, ROOF_COLORS[rng.randi() % ROOF_COLORS.size()])
	# chimney, porch roof on posts, and a garage annex on the side (cars live there)
	b.box(ctx.root, Vector3(1.0, 3.0, 1.0), _at(ctx, pos, w * 0.3, -d * 0.1, h + 1.8), Color(0.45, 0.25, 0.2))
	b.box(ctx.root, _oriented(ctx, 4.0, 0.2, 2.2), _at(ctx, pos, 0, d * 0.5 + 1.1, 2.7), Color(0.3, 0.22, 0.18))
	for sgn in [-1.0, 1.0]:
		b.box(ctx.root, Vector3(0.2, 2.7, 0.2), _at(ctx, pos, sgn * 1.8, d * 0.5 + 2.0, 1.35), Color(0.85, 0.85, 0.85))
	var side := 1.0 if int(ctx.lot.id) % 2 == 0 else -1.0
	var gx := w * 0.5 + 3.2
	if gx < 14.0:
		b.solid_box(ctx.root, _oriented(ctx, 6.0, 3.2, d * 0.6), _at(ctx, pos, side * gx, -d * 0.2, 1.6), col.darkened(0.15))
		b.box(ctx.root, _oriented(ctx, 4.6, 2.4, 0.2), _at(ctx, pos, side * gx, d * 0.1 + 0.1, 1.2), Color(0.8, 0.8, 0.82))
	_number(ctx, pos, d)
	_front_garden(ctx, pos, w, d, 1.0 if side < 0.0 else -1.0)
	if rng.randf() < 0.5:
		b.tree(ctx.root, _at(ctx, pos, -w * 0.5 - 3.0, d * 0.5 + 3.0, 0.0), rng)


## A villa: low, wide and white, flat roof with an overhang, big glazing, a walled garden and a pool.
func villa(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var w := 26.0
	var d := 17.0
	var h := FLOOR_H * 2.0
	var col: Color = VILLA_COLORS[rng.randi() % VILLA_COLORS.size()]
	var pos := _center(ctx, d)
	# two staggered wings give it the villa silhouette: a tall block and a low one
	b.solid_box_mat(ctx.root, _oriented(ctx, w * 0.6, h, d), _at(ctx, pos, -w * 0.2, 0, h * 0.5), facade(col, w * 0.6, h, 1.8, int(ctx.lot.id)))
	b.solid_box_mat(ctx.root, _oriented(ctx, w * 0.4, FLOOR_H, d * 0.8), _at(ctx, pos, w * 0.3, -d * 0.1, FLOOR_H * 0.5), facade(col, w * 0.4, FLOOR_H, 1.8, int(ctx.lot.id) + 1))
	b.box(ctx.root, _oriented(ctx, w * 0.6 + 1.6, 0.4, d + 1.6), _at(ctx, pos, -w * 0.2, 0, h + 0.2), Color(0.25, 0.25, 0.28))
	b.box(ctx.root, _oriented(ctx, w * 0.4 + 1.2, 0.35, d * 0.8 + 1.2), _at(ctx, pos, w * 0.3, -d * 0.1, FLOOR_H + 0.18), Color(0.25, 0.25, 0.28))
	# a balcony with a glass rail on the upper floor, and a big lit window wall below
	b.box(ctx.root, _oriented(ctx, w * 0.5, 0.2, 2.2), _at(ctx, pos, -w * 0.2, d * 0.5 + 1.1, FLOOR_H), Color(0.8, 0.8, 0.8))
	b.lit_box(ctx.root, _oriented(ctx, w * 0.45, 1.0, 0.1), _at(ctx, pos, -w * 0.2, d * 0.5 + 2.2, FLOOR_H + 0.7), Color(0.6, 0.85, 1.0), 0.6)
	b.lit_box(ctx.root, _oriented(ctx, w * 0.35, 2.2, 0.12), _front(ctx, pos, d) + ctx.across * (-w * 0.2) + Vector3(0, 1.3, 0), Color(1.0, 0.9, 0.7), 1.1)
	_door(ctx, pos, d, Color(0.2, 0.12, 0.08), 1.6, 2.5)
	# garden wall across the front with a gate gap, and the pool at the back
	for sgn in [-1.0, 1.0]:
		b.solid_box(ctx.root, _oriented(ctx, 11.0, 1.4, 0.4), _at(ctx, pos, sgn * 7.8, d * 0.5 + 6.0, 0.7), col.darkened(0.1))
	b.lit_box(ctx.root, _oriented(ctx, 8.0, 0.1, 4.0), _at(ctx, pos, w * 0.1, -d * 0.5 - 1.0, 0.06), Color(0.2, 0.7, 0.95), 1.2)
	for sgn in [-1.0, 1.0]:
		b.tree(ctx.root, _at(ctx, pos, sgn * (w * 0.5 + 1.5), d * 0.3, 0.0), rng)
	_number(ctx, pos, d, 3.4)


## An apartment block: five to nine floors of windows, balconies up the front, a canopy at the
## entrance and plant on the flat roof.
func apartment(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var w := 20.0
	var d := 20.0
	var floors := rng.randi_range(5, 9)
	var h := FLOOR_H * floors
	var col: Color = BRICK_COLORS[rng.randi() % BRICK_COLORS.size()] if rng.randf() < 0.5 else CONCRETE_COLORS[rng.randi() % CONCRETE_COLORS.size()]
	var pos := _center(ctx, d)
	b.solid_box_mat(ctx.root, _oriented(ctx, w, h, d), _at(ctx, pos, 0, 0, h * 0.5), facade(col, w, h, 1.5, int(ctx.lot.id)))
	# roof: parapet slab, lift housing, water tank
	b.box(ctx.root, _oriented(ctx, w + 0.6, 0.6, d + 0.6), _at(ctx, pos, 0, 0, h + 0.3), col.darkened(0.3))
	b.box(ctx.root, _oriented(ctx, 4.0, 2.6, 4.0), _at(ctx, pos, -w * 0.25, -d * 0.2, h + 1.9), Color(0.5, 0.5, 0.52))
	var tank := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 1.6
	cm.bottom_radius = 1.6
	cm.height = 2.4
	tank.mesh = cm
	tank.material_override = b.mat(Color(0.4, 0.35, 0.3))
	tank.position = _at(ctx, pos, w * 0.25, -d * 0.15, h + 1.8)
	ctx.root.add_child(tank)
	# balconies on every other floor, with glass rails
	var f2 := 2
	while f2 < floors:
		var y := f2 * FLOOR_H
		for sgn in [-1.0, 1.0]:
			b.box(ctx.root, _oriented(ctx, 5.0, 0.2, 1.6), _at(ctx, pos, sgn * 5.0, d * 0.5 + 0.8, y), Color(0.7, 0.7, 0.72))
			b.lit_box(ctx.root, _oriented(ctx, 5.0, 0.9, 0.08), _at(ctx, pos, sgn * 5.0, d * 0.5 + 1.6, y + 0.6), Color(0.6, 0.85, 1.0), 0.5)
		f2 += 2
	# stone plinth round the base, a cornice under the roof, and a set-back penthouse floor
	b.box(ctx.root, _oriented(ctx, w + 0.4, 1.0, d + 0.4), _at(ctx, pos, 0, 0, 0.5), col.darkened(0.35))
	b.box(ctx.root, _oriented(ctx, w + 0.8, 0.5, d + 0.8), _at(ctx, pos, 0, 0, h - 0.25), col.lightened(0.15))
	if floors >= 7:
		b.solid_box_mat(ctx.root, _oriented(ctx, w * 0.6, FLOOR_H, d * 0.6), _at(ctx, pos, 0, 0, h + 0.6 + FLOOR_H * 0.5), facade(col, w * 0.6, FLOOR_H, 1.8, int(ctx.lot.id) + 2))
	# entrance: glass doors under a canopy
	b.lit_box(ctx.root, _oriented(ctx, 3.2, 2.6, 0.15), _front(ctx, pos, d) + Vector3(0, 1.3, 0), Color(0.9, 0.95, 1.0), 0.9)
	b.box(ctx.root, _oriented(ctx, 5.0, 0.25, 2.4), _at(ctx, pos, 0, d * 0.5 + 1.2, 3.2), Color(0.25, 0.25, 0.28))
	_number(ctx, pos, d, 3.6)


## A glass office tower in the busy parts: tall, blue and lit, with a lobby and a company name on top.
func office(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var w := 22.0
	var d := 20.0
	var floors := rng.randi_range(8, 15)
	var h := FLOOR_H * floors
	var col := Color(0.42, 0.55, 0.68).lerp(Color(0.55, 0.62, 0.7), rng.randf())
	var pos := _center(ctx, d)
	b.solid_box_mat(ctx.root, _oriented(ctx, w, h, d), _at(ctx, pos, 0, 0, h * 0.5), facade(col, w, h, 2.0, int(ctx.lot.id)))
	b.box(ctx.root, _oriented(ctx, w + 0.4, 0.8, d + 0.4), _at(ctx, pos, 0, 0, h + 0.4), Color(0.2, 0.2, 0.24))
	b.box(ctx.root, _oriented(ctx, 6.0, 3.0, 6.0), _at(ctx, pos, 0, 0, h + 2.3), Color(0.35, 0.35, 0.4))
	b.box(ctx.root, Vector3(0.2, 9.0, 0.2), _at(ctx, pos, 0, 0, h + 7.5), Color(0.6, 0.6, 0.64))
	b.lit_box(ctx.root, Vector3(0.4, 0.4, 0.4), _at(ctx, pos, 0, 0, h + 12.2), Color(1.0, 0.1, 0.1), 3.0)
	b.box(ctx.root, _oriented(ctx, w + 0.6, 1.2, d + 0.6), _at(ctx, pos, 0, 0, 0.6), Color(0.25, 0.27, 0.32))
	for sgn in [-1.0, 1.0]:
		b.box(ctx.root, Vector3(0.7, h, 0.7), _at(ctx, pos, sgn * (w * 0.5 + 0.1), d * 0.5 + 0.1, h * 0.5), Color(0.28, 0.3, 0.35))
	b.lit_box(ctx.root, _oriented(ctx, w * 0.8, 3.4, 0.2), _front(ctx, pos, d) + Vector3(0, 1.8, 0), Color(0.7, 0.85, 0.95), 0.6)
	b.box(ctx.root, _oriented(ctx, 9.0, 0.3, 3.0), _at(ctx, pos, 0, d * 0.5 + 1.5, 3.8), Color(0.2, 0.2, 0.24))
	_sign(ctx, pos, d, OFFICE_NAMES[rng.randi() % OFFICE_NAMES.size()], h + 5.0, Color(0.8, 0.95, 1.0), 120)
	_number(ctx, pos, d, 4.4)


## A shop with flats above: a lit shopfront and awning on the ground floor, windows above.
func shop(ctx: Dictionary) -> void:
	var rng: RandomNumberGenerator = ctx.rng
	var w := 24.0
	var d := 20.0
	var floors := rng.randi_range(2, 4)
	var h := FLOOR_H * floors + 1.0
	var col: Color = SHOP_COLORS[rng.randi() % SHOP_COLORS.size()]
	var pos := _center(ctx, d)
	_shop_body(ctx, pos, w, d, h, col, SHOP_NAMES[rng.randi() % SHOP_NAMES.size()], Color(1, 0.9, 0.5), 96)
	b.box(ctx.root, _oriented(ctx, w + 0.4, 0.5, d + 0.4), _at(ctx, pos, 0, 0, h + 0.25), col.darkened(0.4))
	for k in 2:
		b.box(ctx.root, _oriented(ctx, 2.2, 1.2, 1.8), _at(ctx, pos, -w * 0.25 + k * w * 0.4, -d * 0.2, h + 1.1), Color(0.55, 0.57, 0.6))
	b.box(ctx.root, _oriented(ctx, w + 0.3, 0.5, 0.3), _at(ctx, pos, 0, d * 0.5 + 0.15, FLOOR_H + 0.5), col.darkened(0.2))
	_number(ctx, pos, d)


func special(ctx: Dictionary) -> void:
	var kind: String = ctx.lot.special
	var col: Color = SPECIAL_COLORS.get(kind, Color(0.6, 0.6, 0.6))
	var d := 22.0
	var pos := _center(ctx, d)
	_shop_body(ctx, pos, 26.0, d, 11.0, col, SPECIAL_LABELS.get(kind, kind.to_upper()), Color(1, 1, 1), 96)
	ctx.size = _oriented(ctx, 26.0, 11.0, d)
	ctx.pos = pos
	_number(ctx, pos, d)


## The crew's house: bright and warm, a lamp at the door and HOME over the roof.
func home(ctx: Dictionary) -> void:
	var w := 18.0
	var d := 18.0
	var h := FLOOR_H * 2.0
	var pos := _center(ctx, d)
	b.solid_box_mat(ctx.root, _oriented(ctx, w, h, d), _at(ctx, pos, 0, 0, h * 0.5), facade(Color(0.95, 0.8, 0.45), w, h, 2.2, 7))
	_door(ctx, pos, d, Color(0.25, 0.15, 0.1))
	_roof_prism(ctx, pos, w, d, h, Color(0.45, 0.2, 0.15))
	b.box(ctx.root, Vector3(1.0, 3.0, 1.0), _at(ctx, pos, w * 0.3, -d * 0.1, h + 1.8), Color(0.45, 0.25, 0.2))
	_sign(ctx, pos, d, "HOME", h + 5.0, Color(1, 0.95, 0.6), 140)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.8, 0.5)
	lamp.light_energy = 3.0
	lamp.omni_range = 30.0
	lamp.position = pos + Vector3(0, 6.0, 0) + ctx.f * (d * 0.5 + 4.0)
	ctx.root.add_child(lamp)
	_number(ctx, pos, d)


## Shared by shops and landmark buildings: facade with floors of windows, lit glass shopfront at the
## bottom, an awning, and the name above the door.
func _shop_body(ctx: Dictionary, pos: Vector3, w: float, d: float, h: float, col: Color, label: String, label_col: Color, size: int) -> void:
	b.solid_box_mat(ctx.root, _oriented(ctx, w, h, d), _at(ctx, pos, 0, 0, h * 0.5), facade(col, w, h, 1.4, int(ctx.lot.id)))
	b.lit_box(ctx.root, _oriented(ctx, w * 0.78, 2.7, 0.15), _front(ctx, pos, d) + Vector3(0, 1.6, 0), Color(0.75, 0.82, 0.95), 0.4)
	b.box(ctx.root, _oriented(ctx, w * 0.9, 0.2, 1.8), _at(ctx, pos, 0, d * 0.5 + 0.9, 3.6), col.darkened(0.3))
	_door(ctx, pos, d, Color(0.2, 0.15, 0.1))
	_sign(ctx, pos, d, label, 5.0 + FLOOR_H, label_col, size)


## Lawn, a path to the door, a low fence with a gate gap, and a hedge down one side.
func _front_garden(ctx: Dictionary, pos: Vector3, w: float, d: float, hedge_side: float) -> void:
	var out := d * 0.5 + 4.2
	b.box(ctx.root, _oriented(ctx, w + 6.0, 0.06, 7.0), _at(ctx, pos, 0, d * 0.5 + 3.5, 0.03), Color(0.14, 0.3, 0.14))
	b.box(ctx.root, _oriented(ctx, 1.4, 0.08, 7.0), _at(ctx, pos, 0, d * 0.5 + 3.5, 0.06), Color(0.6, 0.58, 0.54))
	for sgn in [-1.0, 1.0]:
		b.solid_box(ctx.root, _oriented(ctx, (w + 6.0) * 0.5 - 1.2, 0.9, 0.12), _at(ctx, pos, sgn * ((w + 6.0) * 0.25 + 0.6), out + 2.4, 0.45), Color(0.9, 0.9, 0.88))
	b.solid_box(ctx.root, _oriented(ctx, 0.5, 1.1, 5.0), _at(ctx, pos, hedge_side * (w * 0.5 + 2.0), d * 0.5 + 2.4, 0.55), Color(0.1, 0.32, 0.12))


# --- Open houses ------------------------------------------------------------------------------

## Walls with a gap at the front door, a ceiling, a rug, a couch and a telly. Everything is solid
## except the doorway.
func _open_house(ctx: Dictionary, pos: Vector3, w: float, d: float, h: float, col: Color) -> void:
	var house := Node3D.new()
	house.name = "OpenHouse_%d" % int(ctx.lot.id)
	ctx.root.add_child(house)
	var inner := {"root": house, "f": ctx.f, "across": ctx.across}
	# (centre along-street, centre along-facing, length along-street, length along-facing)
	var walls := [
		[0.0, -(d * 0.5 - WALL * 0.5), w, WALL],
		[-(w * 0.5 - WALL * 0.5), 0.0, WALL, d],
		[w * 0.5 - WALL * 0.5, 0.0, WALL, d],
	]
	var side_w := (w - DOOR_GAP) * 0.5
	for sgn in [-1.0, 1.0]:
		walls.append([sgn * (DOOR_GAP * 0.5 + side_w * 0.5), d * 0.5 - WALL * 0.5, side_w, WALL])
	var idx := 0
	for wl in walls:
		var mi := b.solid_box_mat(house, _oriented(inner, wl[2], h, wl[3]), _at(inner, pos, wl[0], wl[1], h * 0.5), facade(col, maxf(wl[2], wl[3]), h, 1.3, int(ctx.lot.id)))
		mi.name = "Wall%d" % idx
		idx += 1
	var lintel_h := h - 2.4
	b.solid_box(house, _oriented(inner, DOOR_GAP, lintel_h, WALL), _at(inner, pos, 0, d * 0.5 - WALL * 0.5, 2.4 + lintel_h * 0.5), col).name = "Lintel"
	b.solid_box(house, _oriented(inner, w, WALL, d), _at(inner, pos, 0, 0, h + WALL * 0.5), col.darkened(0.2)).name = "Ceiling"
	b.lit_box(house, _oriented(inner, w * 0.5, 0.05, d * 0.4), _at(inner, pos, 0, 0, h - 0.05), Color(1.0, 0.85, 0.55), 1.4)
	b.box(house, _oriented(inner, w * 0.45, 0.04, d * 0.4), _at(inner, pos, 0, 0, 0.05), Color(0.55, 0.2, 0.25))
	b.box(house, _oriented(inner, w * 0.5, 0.8, 0.9), _at(inner, pos, 0, -(d * 0.5 - 1.2), 0.45), Color(0.3, 0.35, 0.5))
	b.lit_box(house, _oriented(inner, 1.2, 0.8, 0.1), _at(inner, pos, -(w * 0.5 - 0.6), 0, 1.1), Color(0.4, 0.7, 1.0), 1.2)
