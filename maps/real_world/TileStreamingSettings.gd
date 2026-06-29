# TileStreamingSettings.gd — Configurazioni performance per streaming 3D Tiles
# ==================================================================================
# Gestisce qualità/LOD, distanza di caricamento, limite memoria,
# e fallback offline. Caricato come risorsa da MapLoader.gd.

class_name TileStreamingSettings
extends Resource

enum QualityPreset {
	LOW,
	MEDIUM,
	HIGH,
}

@export var quality: QualityPreset = QualityPreset.MEDIUM
@export var max_screen_space_error: float = 16.0
@export var max_distance: float = 3000.0         # metri dal player
@export var memory_cache_mb: int = 512
@export var max_concurrent_downloads: int = 8
@export var skip_level_of_detail: bool = false
@export var enable_frustum_culling: bool = true
@export var prefer_google_tiles: bool = false     # se disponibile, usa tiles Google


func apply_preset(preset: QualityPreset) -> void:
	quality = preset
	match preset:
		QualityPreset.LOW:
			max_screen_space_error = 32.0
			max_distance = 1500.0
			memory_cache_mb = 128
			max_concurrent_downloads = 4
			skip_level_of_detail = true
		QualityPreset.MEDIUM:
			max_screen_space_error = 16.0
			max_distance = 3000.0
			memory_cache_mb = 512
			max_concurrent_downloads = 8
			skip_level_of_detail = false
		QualityPreset.HIGH:
			max_screen_space_error = 8.0
			max_distance = 5000.0
			memory_cache_mb = 1024
			max_concurrent_downloads = 12
			skip_level_of_detail = false


func get_settings_as_dict() -> Dictionary:
	return {
		"quality": quality,
		"max_screen_space_error": max_screen_space_error,
		"max_distance": max_distance,
		"memory_cache_mb": memory_cache_mb,
		"max_concurrent_downloads": max_concurrent_downloads,
		"skip_level_of_detail": skip_level_of_detail,
		"enable_frustum_culling": enable_frustum_culling,
		"prefer_google_tiles": prefer_google_tiles,
	}


static func from_config_file(path: String = "res://config/map_settings.cfg") -> TileStreamingSettings:
	var settings := TileStreamingSettings.new()
	var cfg := ConfigFile.new()
	if cfg.load(path) == OK:
		var q: String = cfg.get_value("streaming", "quality", "medium")
		match q:
			"low":    settings.apply_preset(QualityPreset.LOW)
			"high":   settings.apply_preset(QualityPreset.HIGH)
			_:        settings.apply_preset(QualityPreset.MEDIUM)
		settings.max_screen_space_error = cfg.get_value("streaming", "max_sse", settings.max_screen_space_error)
		settings.max_distance = cfg.get_value("streaming", "max_distance", settings.max_distance)
		settings.memory_cache_mb = cfg.get_value("streaming", "memory_mb", settings.memory_cache_mb)
		settings.max_concurrent_downloads = cfg.get_value("streaming", "max_downloads", settings.max_concurrent_downloads)
		settings.prefer_google_tiles = cfg.get_value("streaming", "use_google", false)
	return settings
