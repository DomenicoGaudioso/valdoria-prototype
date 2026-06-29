# CitySelectionMenu.gd — Menu UI per selezionare la città reale 3D
# ==================================================================================
# Scena: CitySelectionMenu.tscn (Control esteso)
# Mostra l'elenco città divise per stato (verificate, da testare, preferite),
# permette selezione e avvia il caricamento tramite MapLoader.

extends Control

signal city_chosen(city_id: String)
signal back_pressed()

const CityDatabase = preload("res://maps/real_world/CityDatabase.gd")

var _city_buttons: Dictionary = {}
var _filter_verified_only: bool = false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	# Sfondo
	var bg := ColorRect.new()
	bg.name = "Background"; bg.anchor_right = 1.0; bg.anchor_bottom = 1.0
	bg.color = Color(0.03, 0.04, 0.08, 0.97)
	add_child(bg)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.anchor_left = 0.05; main_vbox.anchor_top = 0.03
	main_vbox.anchor_right = 0.95; main_vbox.anchor_bottom = 0.97
	add_child(main_vbox)

	# Titolo
	var title := Label.new()
	title.name = "Title"
	title.text = "SELEZIONA CITTA REALE (3D Tiles)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.55, 0.88, 1.0))
	main_vbox.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "Streaming fotorealistico via Cesium ion / Google 3D Tiles"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 12)
	subtitle.add_theme_color_override("font_color", Color(0.5, 0.7, 0.8))
	main_vbox.add_child(subtitle)

	main_vbox.add_child(_make_separator())

	# Toggle filtro
	var filter_row := HBoxContainer.new()
	var filter_label := Label.new()
	filter_label.text = "Mostra solo città verificate  "
	filter_label.add_theme_font_size_override("font_size", 13)
	filter_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	filter_row.add_child(filter_label)

	var filter_check := CheckBox.new()
	filter_check.name = "FilterCheck"
	filter_check.toggled.connect(func(on: bool):
		_filter_verified_only = on
		_refresh_city_list()
	)
	filter_row.add_child(filter_check)
	main_vbox.add_child(filter_row)

	main_vbox.add_child(_make_separator())

	# Scroll container per le città
	var scroll := ScrollContainer.new()
	scroll.name = "CityScroll"; scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	var city_grid := GridContainer.new()
	city_grid.name = "CityGrid"; city_grid.columns = 2
	city_grid.add_theme_constant_override("h_separation", 12)
	city_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(city_grid)

	_populate_cities(city_grid)

	# Pulsanti azione
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)

	var back_btn := Button.new()
	back_btn.name = "BackBtn"; back_btn.text = "Indietro (Mappa Classica)"
	back_btn.custom_minimum_size = Vector2(220, 50)
	_style_button(back_btn)
	back_btn.pressed.connect(func(): back_pressed.emit())
	btn_row.add_child(back_btn)

	main_vbox.add_child(btn_row)


func _populate_cities(grid: GridContainer) -> void:
	_city_buttons.clear()
	var cities := CityDatabase.get_all_cities()
	for city_id in cities:
		var city: Dictionary = cities[city_id]
		if _filter_verified_only and city.status != CityDatabase.CityStatus.VERIFIED and city.status != CityDatabase.CityStatus.FAVORITE:
			continue
		var card := _make_city_card(city)
		grid.add_child(card)
		_city_buttons[city_id] = card


func _make_city_card(city: Dictionary) -> Panel:
	var panel := Panel.new()
	panel.custom_minimum_size = Vector2(380, 90)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.05, 0.07, 0.12, 0.95)
	ps.border_width_left = 1; ps.border_width_right = 1
	ps.border_width_top = 1; ps.border_width_bottom = 1

	var border_color := Color(0.3, 0.5, 0.7)
	match city.status:
		CityDatabase.CityStatus.VERIFIED:
			border_color = Color(0.2, 0.8, 0.3)
		CityDatabase.CityStatus.TO_TEST:
			border_color = Color(0.8, 0.6, 0.2)
		CityDatabase.CityStatus.FAVORITE:
			border_color = Color(1.0, 0.7, 0.2)
	ps.border_color = border_color
	panel.add_theme_stylebox_override("panel", ps)

	var vbox := VBoxContainer.new()
	vbox.anchor_left = 0.03; vbox.anchor_top = 0.05
	vbox.anchor_right = 0.97; vbox.anchor_bottom = 0.95
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	var name_label := Label.new()
	name_label.text = city.display_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.85))
	vbox.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = city.description
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	var info_row := HBoxContainer.new()
	var coords_label := Label.new()
	coords_label.text = "%.4f, %.4f" % [city.lat, city.lon]
	coords_label.add_theme_font_size_override("font_size", 10)
	coords_label.add_theme_color_override("font_color", Color(0.4, 0.5, 0.6))
	info_row.add_child(coords_label)

	var status_label := Label.new()
	var status_texts := {
		CityDatabase.CityStatus.VERIFIED: "[VERIFICATA]",
		CityDatabase.CityStatus.TO_TEST: "[DA TESTARE]",
		CityDatabase.CityStatus.FAVORITE: "[PREFERITA]",
	}
	var status_colors := {
		CityDatabase.CityStatus.VERIFIED: Color(0.3, 0.9, 0.3),
		CityDatabase.CityStatus.TO_TEST: Color(0.9, 0.7, 0.3),
		CityDatabase.CityStatus.FAVORITE: Color(1.0, 0.8, 0.2),
	}
	status_label.text = "  " + status_texts.get(city.status, "")
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", status_colors.get(city.status, Color.GRAY))
	info_row.add_child(status_label)
	vbox.add_child(info_row)

	# Click per selezionare
	panel.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			city_chosen.emit(city.id)
	)

	return panel


func _refresh_city_list() -> void:
	var grid := get_node_or_null("MainVBox/CityScroll/CityGrid") as GridContainer
	if not grid:
		return
	for child in grid.get_children():
		child.queue_free()
	_populate_cities(grid)


func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	return sep


func _style_button(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.08, 0.14, 0.96)
	normal.border_width_left = 1; normal.border_width_right = 1
	normal.border_width_top = 1; normal.border_width_bottom = 1
	normal.border_color = Color(0.25, 0.7, 0.95, 0.72)
	normal.corner_radius_top_left = 3; normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3; normal.corner_radius_bottom_right = 3

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.1, 0.12, 0.2, 0.98)
	hover.border_color = Color(0.66, 0.28, 1.0, 0.88)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_color_override("font_color", Color(0.75, 0.92, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.94, 0.82, 1.0))
	btn.add_theme_font_size_override("font_size", 14)
