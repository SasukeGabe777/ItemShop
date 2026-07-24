extends Node
## Replica: entity replication for online play — spawn/despawn/state/events
## for host-simulated entities (enemies, customers, projectiles, loot) plus
## per-player body streams. The full layer lands with the dungeon/shop
## milestones; offline and couch play never touch it.
##
## Every message carries `gen`, a scene-generation stamp bumped by each
## SceneRouter.go on every machine (host-ordered scene changes keep the
## counters aligned), so stragglers from a dying scene are dropped instead of
## resurrecting freed nodes.

var gen: int = 0

var _factories: Dictionary = {}  # kind -> Callable(args) -> Node
var _entities: Dictionary = {}   # eid -> Node
var _next_eid := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Called on every machine for every scene change (see SceneRouter.go).
func bump_gen() -> void:
	gen += 1
	_entities.clear()
	_factories.clear()  # the incoming scene re-registers its factories
	_next_eid = 1


## The active scene registers how to build local puppets for each entity kind.
func register_factory(kind: String, factory: Callable) -> void:
	_factories[kind] = factory


func entity(eid: int) -> Node:
	var node: Variant = _entities.get(eid)
	return node if node is Node and is_instance_valid(node) else null
