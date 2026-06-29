# RealCityRegistry.gd - legacy OSM city registry
#
# Le vecchie citta OSM/OSM2World non sviluppate sono state rimosse dal gioco.
# Le mappe 3D realmente disponibili ora vivono in LocalGltfMapRegistry.gd,
# perche sono asset locali completi estratti dagli zip in maps/real_world.

extends Node

enum CityStatus {
	TODO,
	CONVERTED,
	IMPORTED,
	READY,
	FAVORITE,
}

const ALL_CITIES: Dictionary = {}


static func get_city(city_id: String) -> Dictionary:
	push_warning("RealCityRegistry: citta legacy rimossa o non sviluppata: %s" % city_id)
	return {}


static func get_all() -> Dictionary:
	return ALL_CITIES


static func get_ids() -> PackedStringArray:
	return PackedStringArray()


static func get_ready() -> Dictionary:
	return {}


static func get_italian() -> Dictionary:
	return {}


static func set_status(_city_id: String, _new_status: int) -> void:
	pass


static func set_favorite(_city_id: String, _fav: bool) -> void:
	pass
