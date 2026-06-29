# LoadingMapScreen.gd — Schermata di caricamento durante lo streaming 3D Tiles
# ==================================================================================
# Mostra una progress bar e uno status text mentre i tiles vengono caricati.
# Collegata a MapLoader.loading_progress per aggiornamenti in tempo reale.

extends Control

@export var map_loader: Node   # MapLoader reference

var _progress_bar: ProgressBar
var _status_label: Label
var _tip_label: Label
var _started: bool = false

var _loading_tips: Array[String] = [
	"Le citta reali usano dati fotogrammetrici 3D da Cesium ion.",
	"Lo streaming carica solo i tiles visibili dalla camera.",
	"La qualita puo essere regolata nelle impostazioni.",
	"Alcune citta potrebbero richiedere piu tempo al primo caricamento.",
	"Il plugin 3D Tiles for Godot gestisce il LOD automaticamente.",
	"Per mappe offline, usa la modalita classica 2D isometrica.",
	"I dati 3D Tiles di Google richiedono una Map Tiles API key.",
	"Venezia e Roma sono in fase di test — segnala eventuali problemi.",
]


func _ready() -> void:
	_build_ui()
	if map_loader and map_loader.has_signal("loading_progress"):
		map_loader.loading_progress.connect(_on_loading_progress)


func _build_ui() -> void:
	# Sfondo animato scuro
	var bg := ColorRect.new()
	bg.name = "Background"; bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0.02, 0.03, 0.08, 0.98)
	add_child(bg)

	var center := VBoxContainer.new()
	center.anchor_left = 0.25; center.anchor_right = 0.75
	center.anchor_top = 0.35; center.anchor_bottom = 0.65
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 24)
	add_child(center)

	# Titolo
	var title := Label.new()
	title.name = "Title"
	title.text = "CARICAMENTO CITTA REALE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	center.add_child(title)

	# Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 1.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(400, 28)
	_progress_bar.show_percentage = false

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.05, 0.08, 0.15, 0.9)
	bg_style.border_width_left = 1; bg_style.border_width_right = 1
	bg_style.border_width_top = 1; bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.2, 0.5, 0.7)
	_progress_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.2, 0.65, 1.0)
	_progress_bar.add_theme_stylebox_override("fill", fill_style)
	center.add_child(_progress_bar)

	# Status
	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "Inizializzazione..."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 14)
	_status_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	center.add_child(_status_label)

	# Tips
	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.text = _random_tip()
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.add_theme_font_size_override("font_size", 12)
	_tip_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(_tip_label)

	# Timer per cambiare i tips
	var tip_timer := Timer.new()
	tip_timer.name = "TipTimer"
	tip_timer.wait_time = 4.0
	tip_timer.timeout.connect(func(): _tip_label.text = _random_tip())
	tip_timer.autostart = true
	add_child(tip_timer)


func _on_loading_progress(progress: float, status: String) -> void:
	if not _started:
		_started = true
	_progress_bar.value = clamp(progress, 0.0, 1.0)
	_status_label.text = status


func _random_tip() -> String:
	return _loading_tips[randi() % _loading_tips.size()]


func show_screen() -> void:
	visible = true
	_started = false
	_progress_bar.value = 0.0
	_status_label.text = "Inizializzazione..."


func hide_screen() -> void:
	visible = false
