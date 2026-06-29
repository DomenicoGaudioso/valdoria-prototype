# CitySelector.gd — Logica di selezione e configurazione della città 3D
# ==================================================================================
# Accoppiato a CitySelectionMenu.tscn. Gestisce la selezione utente,
# la configurazione geografica e il passaggio dati al MapLoader.

extends Node

signal city_selected(city_data: Dictionary)
signal selection_cancelled()

var _selected_city_id: String = ""
var _cities: Dictionary = {}


func _ready() -> void:
	_cities = CityDatabase.get_all_cities()


func select_city(city_id: String) -> void:
	if not _cities.has(city_id):
		push_warning("CitySelector: città '%s' non valida." % city_id)
		return
	_selected_city_id = city_id
	var city_data: Dictionary = _cities[city_id]
	print("CitySelector: selezionata %s (%.4f, %.4f)" % [city_data.display_name, city_data.lat, city_data.lon])
	city_selected.emit(city_data)


func get_selected_city() -> Dictionary:
	if _selected_city_id.is_empty():
		return {}
	return _cities.get(_selected_city_id, {})


func get_wgs84_position() -> Dictionary:
	var city := get_selected_city()
	if city.is_empty():
		return {}
	return {"lat": city.lat, "lon": city.lon, "height": city.height}


func get_cesium_asset_id() -> int:
	var city := get_selected_city()
	return city.get("cesium_asset_id", 0)


func get_google_tileset_id() -> String:
	var city := get_selected_city()
	return city.get("google_tileset_id", "")


func get_preferred_provider() -> String:
	var city := get_selected_city()
	return city.get("preferred_provider", "cesium")
