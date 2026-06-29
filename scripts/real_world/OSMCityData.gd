# OSMCityData.gd — Resource per dati edifici OSM
# ==============================================
# Contiene gli array di edifici (pos, size, color, type) e strade.
# Popolato da generate_osm_city.py, letto da RealCityController.

class_name OSMCityData
extends Resource

@export var city_name: String = ""
@export var city_display: String = ""
@export var buildings_count: int = 0
@export var roads_count: int = 0

## Array di Dictionary: {"pos": Vector3, "size": Vector3, "color": Color, "type": String}
@export var buildings: Array = []

## Array di PackedVector2Array: ogni elemento e una linea stradale
@export var roads: Array = []
