class_name ShopSite
extends Node
## Gives each reserved shop lot (pharmacy, kebab, pub, garage, pawn) a counter you can walk up to.
## The city calls on_special as each block is built; the counter lives and dies with its block.

var world: Node3D    # the World; untyped because World owns this node
var counters := 0    # how many counters have been built (blocks can be rebuilt)

const SHOPS := ["pharmacy", "kebab", "pub", "garage", "pawn"]
const COLORS := {
	"pharmacy": Color(0.2, 0.8, 0.5), "kebab": Color(0.95, 0.4, 0.15), "pub": Color(0.8, 0.3, 0.2),
	"garage": Color(0.5, 0.6, 0.7), "pawn": Color(0.85, 0.7, 0.25),
}


func on_special(lot: Dictionary, parent: Node3D, _pos: Vector3, _size: Vector3) -> void:
	var kind: String = lot.special
	if not SHOPS.has(kind):
		return
	var it := Interactable.new()
	it.name = "Counter_" + kind
	it.position = Game.city.front_point(lot) - Game.city.block_center(lot.block)
	it.prompt = "[E] %s" % ShopItems.CATALOG[kind].title.capitalize()
	it.range_m = 3.2
	parent.add_child(it)
	var col: Color = COLORS[kind]
	var counter := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.8, 1.0, 0.7)
	counter.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.5
	counter.material_override = m
	counter.position.y = 0.5
	it.add_child(counter)
	it.activated.connect(func(player): world.open_modal(ShopPanel.new(kind), player))
	counters += 1
