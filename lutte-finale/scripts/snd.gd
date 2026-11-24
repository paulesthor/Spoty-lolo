extends Node
# Audio manager (autoload "Snd"): music with cross-fades, pooled sound effects with
# per-sound rate limiting (a horde must not turn into noise), pitch variation, volume options.

const MUSIC := {"march": true, "battle": true, "boss": true, "victory": false, "defeat": false, "folk": true, "techno_bourse": true,
	"lounge": true, "pop": true, "techno_data": true, "valse": true, "cosmos": true, "hymne": true,
	"titre": true, "kolkhoze": true, "caserne": true, "radio": true, "battle2": true, "boss2": true}
var players: Array = []
var next_p := 0
var last := {}
var cache := {}
var mus_a: AudioStreamPlayer
var mus_b: AudioStreamPlayer
var cur_music := ""

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for i in 20:
		var p := AudioStreamPlayer.new(); p.bus = "SFX"; add_child(p); players.append(p)
	mus_a = AudioStreamPlayer.new(); mus_a.bus = "Music"; add_child(mus_a)
	mus_b = AudioStreamPlayer.new(); mus_b.bus = "Music"; add_child(mus_b)
	apply_volumes()

func apply_volumes():
	var m: float = Meta.opt("music") / 100.0
	var s: float = Meta.opt("sfx") / 100.0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(m, 0.0001)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(s, 0.0001)))

func _stream(path: String) -> AudioStream:
	if not cache.has(path):
		cache[path] = load(path) if ResourceLoader.exists(path) else null
	return cache[path]

# play a sound effect; `gap` = minimum seconds between two plays of the same sound
func play(name: String, vol_db := 0.0, pitch_var := 0.08, gap := 0.05, pitch := 1.0):
	if DisplayServer.get_name() == "headless": return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last.get(name, -10.0)) < gap: return
	last[name] = now
	var st := _stream("res://assets/audio/sfx/%s.ogg" % name)
	if st == null: return
	var p: AudioStreamPlayer = players[next_p]
	next_p = (next_p + 1) % players.size()
	p.stream = st
	p.volume_db = vol_db
	p.pitch_scale = pitch * randf_range(1.0 - pitch_var, 1.0 + pitch_var)
	p.play()

func music(name: String, fade := 1.2):
	if DisplayServer.get_name() == "headless": return
	if name == cur_music and mus_a.playing: return
	cur_music = name
	var st: AudioStream = _stream("res://assets/audio/music/%s.ogg" % name)
	if st == null: return
	if st is AudioStreamOggVorbis: (st as AudioStreamOggVorbis).loop = MUSIC.get(name, false)
	# swap players and cross-fade
	var old := mus_a
	mus_a = mus_b; mus_b = old
	mus_a.stream = st
	mus_a.volume_db = -40.0
	mus_a.play()
	var tw := create_tween().set_parallel()
	tw.tween_property(mus_a, "volume_db", 0.0, fade)
	tw.tween_property(mus_b, "volume_db", -60.0, fade)
	tw.chain().tween_callback(mus_b.stop)

func stop_music(fade := 0.8):
	cur_music = ""
	var tw := create_tween()
	tw.tween_property(mus_a, "volume_db", -60.0, fade)
	tw.tween_callback(mus_a.stop)
