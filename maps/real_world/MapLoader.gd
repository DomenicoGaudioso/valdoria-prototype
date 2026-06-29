# MapLoader.gd — Wrapper universale per caricamento mappe (classiche + 3D Tiles)
# ==================================================================================
# Permette di scegliere tra:
#   a) mappa classica interna (GameBootstrap con tileset FLARE)
#   b) città reale 3D Tiles (Cesium ion / Google Photorealistic)
#
# Usato come ponte: il gioco chiama MapLoader.load_map() e questo decide
# quale sistema di caricamento attivare in base alla configurazione.

class_name MapLoader
extends Node

signal map_loaded(map_name: String)
signal map_load_failed(reason: String)
signal loading_progress(progress: float, status: String)

enum MapType {
	CLASSIC_2D_ISOMETRIC,
	REAL_3D_TILES,
}

var _current_map_type: MapType = MapType.CLASSIC_2D_ISOMETRIC
var _settings: TileStreamingSettings
var _city_selector: Node   # CitySelector reference
var _bootstrap_ref: Node   # GameBootstrap reference


func _init(p_settings: TileStreamingSettings = null) -> void:
	if p_settings:
		_settings = p_settings
	else:
		_settings = TileStreamingSettings.from_config_file()


func set_bootstrap(bootstrap: Node) -> void:
	_bootstrap_ref = bootstrap


func set_city_selector(selector: Node) -> void:
	_city_selector = selector


func load_classic_map(map_id: String) -> void:
	_current_map_type = MapType.CLASSIC_2D_ISOMETRIC
	loading_progress.emit(0.0, "Caricamento mappa classica: %s" % map_id)
	if _bootstrap_ref and _bootstrap_ref.has_method("_load_map"):
		_bootstrap_ref._load_map(map_id)
		await get_tree().process_frame
		map_loaded.emit(map_id)
	else:
		map_load_failed.emit("GameBootstrap non disponibile per mappa classica.")


func load_real_city(city_id: String) -> void:
	_current_map_type = MapType.REAL_3D_TILES
	loading_progress.emit(0.0, "Preparazione città reale: %s" % city_id)

	if not _city_selector:
		map_load_failed.emit("CitySelector non configurato.")
		return

	_city_selector.select_city(city_id)

	# Verifica connettività internet (solo per streaming)
	if not _has_internet():
		push_warning("MapLoader: nessuna connessione internet. Uso fallback offline.")
		_activate_fallback()
		map_loaded.emit(city_id)
		return

	loading_progress.emit(0.3, "Inizializzazione Cesium ion...")

	# Il caricamento effettivo dei tiles è delegato a RealWorldMap.tscn
	# che contiene il nodo Cesium3DTileset. Qui emettiamo solo il segnale.
	# La scena RealWorldMap si occuperà di:
	#   1. Configurare CesiumGeoreference con lat/lon della città
	#   2. Settare l'asset ID sul Cesium3DTileset
	#   3. Avviare lo streaming

	loading_progress.emit(0.6, "Streaming tiles in corso...")
	map_loaded.emit(city_id)


func _has_internet() -> bool:
	var http := HTTPRequest.new()
	add_child(http)
	var err := http.request("https://ion.cesium.com/")
	if err != OK:
		http.queue_free()
		return false
	# Timeout breve: se non risponde entro 3 secondi, assumiamo offline
	var timer := get_tree().create_timer(3.0)
	await timer.timeout
	var result := http.get_http_client_status()
	http.queue_free()
	return result == HTTPClient.STATUS_CONNECTED or result == HTTPClient.STATUS_REQUESTING


func _activate_fallback() -> void:
	# Fallback: carica una mappa classica predefinita
	if _bootstrap_ref:
		_bootstrap_ref._load_map("black_oak_city")
	_current_map_type = MapType.CLASSIC_2D_ISOMETRIC
	push_warning("MapLoader: attivato fallback su mappa classica Black Oak City.")


func get_map_type() -> MapType:
	return _current_map_type


func get_settings() -> TileStreamingSettings:
	return _settings
