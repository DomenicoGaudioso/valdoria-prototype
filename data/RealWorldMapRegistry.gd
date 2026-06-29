# RealWorldMapRegistry.gd - legacy registry kept only for compatibility.
#
# Le vecchie scene real_world non sviluppate sono state rimosse dal flusso
# giocabile. Usa LocalGltfMapRegistry.gd per le mappe 3D locali funzionanti.

const MAPS: Dictionary = {}


static func get_map(map_id: String) -> Dictionary:
	push_warning("RealWorldMapRegistry: mappa legacy rimossa o non sviluppata: %s" % map_id)
	return {}


static func get_all() -> Dictionary:
	return MAPS


static func get_ids() -> PackedStringArray:
	return PackedStringArray()
