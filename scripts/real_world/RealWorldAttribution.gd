# RealWorldAttribution.gd — Gestione attribuzioni licenze OpenStreetMap
# =============================================================================
# Requisito legale ODbL: mostrare "© OpenStreetMap contributors" in modo visibile.
# Questo script crea un'etichetta persistente in basso a sinistra.

extends Control

const OSM_ATTRIBUTION: String = "Map data © OpenStreetMap contributors"
const OSM_LICENSE_URL: String = "https://www.openstreetmap.org/copyright"
const OSM_LICENSE: String = "ODbL 1.0"

var _label: Label
var _panel: Panel


func _ready() -> void:
	_panel = Panel.new()
	_panel.name = "AttributionPanel"
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.0, 0.0, 0.0, 0.65)
	ps.corner_radius_top_left = 4
	ps.corner_radius_top_right = 4
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	_label = Label.new()
	_label.name = "AttributionLabel"
	_label.text = OSM_ATTRIBUTION + " | " + OSM_LICENSE
	_label.add_theme_font_size_override("font_size", 10)
	_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65, 0.9))
	_panel.add_child(_label)

	# Posizionamento in basso a sinistra
	anchor_left = 0.0
	anchor_bottom = 1.0
	offset_left = 8.0
	offset_bottom = -8.0

	_label.position = Vector2(6, 2)
	_panel.size = _label.size + Vector2(12, 6)


func set_city_attribution(city_name: String) -> void:
	_label.text = city_name + " — " + OSM_ATTRIBUTION + " | " + OSM_LICENSE
	_panel.size = _label.size + Vector2(12, 6)


func set_custom_attribution(text: String) -> void:
	_label.text = text
	_panel.size = _label.size + Vector2(12, 6)
