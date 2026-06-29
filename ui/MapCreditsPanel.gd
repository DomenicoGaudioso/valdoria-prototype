# MapCreditsPanel.gd — Pannello attribuzioni e licenze per dati mappa
# ==================================================================================
# Mostra i crediti richiesti da Cesium ion, Google, OpenStreetMap e altri provider.
# Accessibile dal menu principale o dalle impostazioni.

extends Control

var _visible: bool = false


func _ready() -> void:
	_build_ui()
	visible = false


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.name = "Background"; bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0.02, 0.03, 0.06, 0.97)
	add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.08; vbox.anchor_top = 0.05
	vbox.anchor_right = 0.92; vbox.anchor_bottom = 0.95
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var title := Label.new()
	title.text = "CREDITI DATI MAPPA / ATTRIBUTIONS"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	vbox.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	scroll.add_child(content)

	# Cesium ion
	content.add_child(_section("CESIUM ION", [
		"3D Tiles e modelli 3D forniti da Cesium ion (https://cesium.com).",
		"Cesium ion e un marchio registrato di Cesium GS, Inc.",
		"Utilizzo soggetto ai Cesium ion Terms of Service.",
		"Attribuzione: 'Includes data from Cesium ion'.",
	], Color(0.3, 0.75, 1.0)))

	# Google Photorealistic 3D Tiles
	content.add_child(_section("GOOGLE PHOTOREALISTIC 3D TILES", [
		"Dati 3D fotorealistici forniti da Google Map Tiles API.",
		"Utilizzo consentito SOLO in streaming runtime, secondo i termini Google.",
		"NON e consentito: download offline, caching permanente, scraping, redistribuzione.",
		"Per mappe offline usare la pipeline OpenStreetMap alternativa.",
		"Google, Google Maps e Photorealistic 3D Tiles sono marchi di Google LLC.",
	], Color(0.9, 0.5, 0.3)))

	# OpenStreetMap
	content.add_child(_section("OPENSTREETMAP", [
		"Dati vettoriali e GIS da OpenStreetMap (https://openstreetmap.org).",
		"© OpenStreetMap contributors, licenza ODbL.",
		"Utilizzato per le mappe isometriche 2D e dati GIS offline.",
	], Color(0.4, 0.8, 0.4)))

	# Plugin
	content.add_child(_section("PLUGIN 3D TILES FOR GODOT", [
		"Plugin '3D Tiles for Godot' di Battle Road (https://github.com/battle-road).",
		"Gestisce lo streaming e rendering di tileset 3D in Godot Engine.",
		"Godot Engine © 2014-present Godot Engine contributors, licenza MIT.",
	], Color(0.6, 0.6, 0.9)))

	# Avviso legale
	content.add_child(_section("AVVISO LEGALE", [
		"Questo software rispetta i termini di licenza di tutti i provider di dati.",
		"I dati 3D in streaming non vengono archiviati permanentemente sul dispositivo.",
		"Per qualsiasi reclamo DMCA o richiesta di rimozione dati, contattare il maintainer.",
	], Color(0.9, 0.8, 0.3)))

	# Close button
	var close_btn := Button.new()
	close_btn.name = "CloseBtn"
	close_btn.text = "Chiudi"
	close_btn.custom_minimum_size = Vector2(0, 44)
	_style_button(close_btn)
	close_btn.pressed.connect(func(): hide_panel())
	vbox.add_child(close_btn)


func _section(title_text: String, lines: Array[String], title_color: Color) -> VBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)

	var t := Label.new()
	t.text = title_text
	t.add_theme_font_size_override("font_size", 16)
	t.add_theme_color_override("font_color", title_color)
	section.add_child(t)

	for line in lines:
		var l := Label.new()
		l.text = "  " + line
		l.add_theme_font_size_override("font_size", 12)
		l.add_theme_color_override("font_color", Color(0.6, 0.65, 0.7))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.add_child(l)

	return section


func show_panel() -> void:
	visible = true
	_visible = true


func hide_panel() -> void:
	visible = false
	_visible = false


func toggle() -> void:
	if _visible:
		hide_panel()
	else:
		show_panel()


func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_color = Color(0.25, 0.7, 0.95, 0.72)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	btn.add_theme_font_size_override("font_size", 14)
