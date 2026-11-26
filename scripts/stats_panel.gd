extends "res://scripts/popup.gd"
## Récords: estadísticas de todas las partidas contra la CPU.

const Stats = preload("res://scripts/stats.gd")

const W := 620.0
var _values: Array = []


func _ready() -> void:
	frame(Rect2(50, 120, W, 1040), "Récords")
	for i in Stats.LABELS.size():
		var row := well(Rect2(30, 92 + i * 66, W - 60, 58))
		label(Stats.LABELS[i][1], UI.CAPTION, UI.LABEL, Rect2(18, 0, 380, 58), row, HORIZONTAL_ALIGNMENT_LEFT)
		_values.append(label("", UI.BODY, UI.GOLD, Rect2(W - 260, 0, 180, 58), row, HORIZONTAL_ALIGNMENT_RIGHT))
	var back := button("Volver", UI.NEUTRAL, Rect2(185, 1040 - 114, 250, UI.TOUCH_SMALL), 28)
	back.pressed.connect(close)


func refresh() -> void:
	for i in Stats.LABELS.size():
		_values[i].text = Stats.value_text(Stats.LABELS[i][0])
