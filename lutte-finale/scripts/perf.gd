class_name Perf
# tiny script profiler for the bot logs: microseconds spent per system, averaged per frame
static var acc := {}
static var frames := 0
static func add(k: String, us: int):
	acc[k] = int(acc.get(k, 0)) + us
	if k == "game": frames += 1
static func report() -> String:
	var parts := []
	for k in acc: parts.append("%s=%.2fms" % [k, acc[k] / 1000.0 / maxf(frames, 1)])
	acc.clear(); frames = 0
	return " ".join(parts)
