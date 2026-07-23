class_name EffectFlipbook
extends Node2D
## One-shot animated effect from a strip sheet (assets/shared/effects/
## processed, built by tools/build_move_vfx.py). Sheets store direction
## variants as rows: [S, SW, W, NW, N, NE, E, SE].

var _sprite: Sprite2D
var _frames: int = 1
var _fps: float = 14.0
var _age: float = 0.0
var _row: int = 0
var _hframes: int = 1


static func dir8(v: Vector2) -> int:
	## row index for a direction, matching the sheet order S,SW,W,NW,N,NE,E,SE
	if v == Vector2.ZERO:
		return 0
	var ang := fposmod(v.angle(), TAU)  # 0 = +x (E), grows toward +y (S/down)
	var octant := int(round(ang / (TAU / 8.0))) % 8   # 0=E,1=SE,2=S,3=SW,4=W,5=NW,6=N,7=NE
	const MAP := [6, 7, 0, 1, 2, 3, 4, 5]
	return MAP[octant]


static func spawn(parent: Node, sheet: String, hframes: int, vframes: int,
		row: int, fps: float, pos: Vector2, scale_by: float = 1.0) -> void:
	if not ResourceLoader.exists(sheet):
		return
	var fx := EffectFlipbook.new()
	fx._sprite = Sprite2D.new()
	fx._sprite.texture = load(sheet)
	fx._sprite.hframes = hframes
	fx._sprite.vframes = vframes
	fx._hframes = hframes
	fx._frames = hframes
	fx._row = clampi(row, 0, vframes - 1)
	fx._fps = fps
	fx._sprite.frame = fx._row * hframes
	fx.add_child(fx._sprite)
	fx.global_position = pos
	fx.scale = Vector2(scale_by, scale_by)
	fx.z_index = 5
	parent.add_child(fx)


func _physics_process(delta: float) -> void:
	_age += delta
	var f := int(_age * _fps)
	if f >= _frames:
		queue_free()
		return
	_sprite.frame = _row * _hframes + f
