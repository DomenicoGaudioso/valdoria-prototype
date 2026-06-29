# RealCityAttribution.gd — Attribuzione OSM per città reali
# =============================================================================
# Mostra l'attribuzione richiesta dalla licenza ODbL in basso a sinistra.
# Requisito legale: "© OpenStreetMap contributors" + link visibile.

extends Control

const OSM_TEXT: String = "© OpenStreetMap contributors"
const OSM_URL: String = "https://www.openstreetmap.org/copyright"
const BBBike_TEXT: String = " | Source: BBBike / Geofabrik"
const OSM2World_TEXT: String = " | 3D: OSM2World"

var _panel: Panel


func _ready() -> void:
	_panel = Panel.new()
	_panel.name = "AttributionPanel"
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.0, 0.0, 0.0, 0.55)
	ps.corner_radius_top_left = 4
	ps.corner_radius_top_right = 4
	_panel.add_theme_stylebox_override("panel", ps)
	add_child(_panel)

	var label := Label.new()
	label.name = "Label"
	label.text = OSM_TEXT + BBBike_TEXT + OSM2World_TEXT
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 0.85))
	_panel.add_child(label)

	anchor_left = 0.0
	anchor_bottom = 1.0
	offset_left = 6.0
	offset_bottom = -6.0

	await get_tree().process_frame
	label.position = Vector2(5, 2)
	_panel.size = label.size + Vector2(10, 5)


func set_city(city_name: String) -> void:
	var label := _panel.get_node_or_null("Label") as Label
	if label:
		label.text = city_name + " — " + OSM_TEXT + BBBike_TEXT + OSM2World_TEXT
		_panel.size = label.size + Vector2(10, 5)
