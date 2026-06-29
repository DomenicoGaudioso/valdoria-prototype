# Real City Maps

The real-city maps are generated from OpenStreetMap data via Overpass API.

Generated maps:

- `roma_centro`
- `venezia_rialto`
- `parigi_cite`
- `berlin_mitte_3d`
- `tokyo_shibuya`

Source cache:

- `data/sources/osm/*.overpass.json`

Generator:

```powershell
python tools\import_osm_city_maps.py
```

The generator rasterizes OSM roads, water, parks, buildings and POIs into the
existing FLARE-style isometric map format used by `GameBootstrap.gd`.

## Attribution

Map data is derived from OpenStreetMap.

Required attribution:

```text
Map data (C) OpenStreetMap contributors
```

License reference:

- https://www.openstreetmap.org/copyright

These maps are stylized derivatives intended for gameplay. They are not
survey-grade GIS outputs and should not be used for navigation.
