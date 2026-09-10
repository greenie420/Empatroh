extends Node
## AudioManager
## Thin wrapper around the audio bus layout (Master / Ambient / Character / FX)
## plus a small pooled player so gameplay code can fire-and-forget SFX
## without worrying about node lifetime.

const POOL_SIZE_PER_BUS := 8

var _pools: Dictionary = {} # bus_name -> Array[AudioStreamPlayer]
var _pool_cursor: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["Ambient", "Character", "FX"]:
		_pools[bus_name] = []
		_pool_cursor[bus_name] = 0
		for i in range(POOL_SIZE_PER_BUS):
			var p := AudioStreamPlayer.new()
			p.bus = bus_name
			add_child(p)
			_pools[bus_name].append(p)


func set_bus_volume_linear(bus_name: String, linear_value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var db := linear_to_db(clampf(linear_value, 0.0, 1.0))
	if linear_value <= 0.0001:
		db = -80.0
	AudioServer.set_bus_volume_db(idx, db)


func get_bus_volume_linear(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


## Fire-and-forget SFX. bus should be "Ambient", "Character" or "FX".
func play_sfx(stream: AudioStream, bus: String = "FX", pitch_variance: float = 0.0, volume_db: float = 0.0) -> void:
	if stream == null or not _pools.has(bus):
		return
	var pool: Array = _pools[bus]
	var cursor: int = _pool_cursor[bus]
	var player: AudioStreamPlayer = pool[cursor]
	_pool_cursor[bus] = (cursor + 1) % pool.size()

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()
