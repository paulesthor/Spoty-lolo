extends Node
# Online coop (autoload "Net"). Filled in by the network layer; solo games never touch it.
var active := false

func to_player(_idx: int, _ev: String, _args: Array):
	pass

func event_all(_ev: String, _args: Array):
	pass

func host_next_zone(_z: int):
	pass
