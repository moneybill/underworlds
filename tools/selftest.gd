extends SceneTree
## Headless smoke test. Drives every screen, then plays a long random expedition and a boss fight.
## Run from the project folder:  godot --headless --path . --script res://tools/selftest.gd
## Uses its own save file, so your real save is never touched. Exit code is the number of failed checks.


func _initialize() -> void:
	_go.call_deferred()


func _go() -> void:
	var runner: Node = load("res://tools/selftest_runner.gd").new()
	root.add_child(runner)
	var failures: int = await runner.run()
	quit(failures)
