# CityDatabase.gd - legacy Cesium/streaming registry
#
# Le citta non sviluppate/placeholder sono state rimosse. Il gioco usa ora
# LocalGltfMapRegistry.gd per le mappe 3D locali effettivamente disponibili.

extends Node

enum CityStatus {
	VERIFIED,
	TO_TEST,
	FAVORITE,
}

const CITIES: Dictionary = {}


static func get_city(city_id: String) -> Dictionary:
	push_warning("CityDatabase: citta streaming rimossa o non sviluppata: %s" % city_id)
	return {}


static func get_all_cities() -> Dictionary:
	return CITIES


static func get_city_ids() -> PackedStringArray:
	return PackedStringArray()


static func get_favorites() -> Dictionary:
	return {}


static func get_verified() -> Dictionary:
	return {}


static func set_favorite(_city_id: String, _favorite: bool) -> void:
	pass
