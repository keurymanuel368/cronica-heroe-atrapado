extends SceneTree
## Lista en JSON todas las líneas con voz (para tools/audio/voces.py).

func _init() -> void:
	var data := preload("res://scripts/cinematics_data.gd")
	var story := preload("res://scripts/story.gd")
	var out: Array = []
	for t in data.INTRO + data.ENDING:
		out.append(["Narrador", t])
	for t in data.CHAPTERS.values():
		out.append(["Narrador", t])
	for t in data.KAITO_INTRO + data.KAITO_END:
		out.append(["Kaito", t])
	for k in data.BOSS_LINES:
		for t in data.BOSS_LINES[k][1]:
			out.append([data.BOSS_LINES[k][0], t])
	for s in story.STEPS:
		if s.has("lines"):
			for t in s.lines:
				out.append([data.VOICE_OF.get(s.npc, s.npc), t])
	var f := FileAccess.open("res://tools/audio/lineas.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(out, " "))
	f.close()
	print("lineas: ", out.size())
	quit()
