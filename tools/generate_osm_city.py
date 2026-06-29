"""
generate_osm_city.py v2 — Esporta dati OSM come Resource Godot (.tres)
========================================================================
Invece di generare un GLB (che ha problemi di rendering in Godot),
esporta un file .tres che contiene gli array di dati per ogni edificio.
Il RealCityController in Godot crea poi BoxMesh direttamente.

Output: assets/real_world/bologna/bologna_buildings.tres
"""

import json
import time
import math
import os

CITY_NAME = "bologna"
CITY_ID = "bologna"

BBOX = {
    "south": 44.4920,
    "west": 11.3385,
    "north": 44.4975,
    "east": 11.3465,
}

LAT_TO_METERS = 111000.0
FLOOR_HEIGHT = 3.2

OVERPASS_URLS = [
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
]

QUERY = f"""
[out:json][timeout:30];
(
  way["building"]({BBOX['south']},{BBOX['west']},{BBOX['north']},{BBOX['east']});
  way["highway"]({BBOX['south']},{BBOX['west']},{BBOX['north']},{BBOX['east']});
  way["natural"="water"]({BBOX['south']},{BBOX['west']},{BBOX['north']},{BBOX['east']});
);
out geom;
"""

TYPE_HEIGHTS = {
    "church": 6, "cathedral": 10, "tower": 12,
    "industrial": 2, "garage": 1, "shed": 1,
    "house": 2, "detached": 2, "terrace": 3,
    "apartments": 5, "residential": 4,
    "commercial": 3, "retail": 2, "office": 5,
    "hotel": 6, "hospital": 5, "school": 3, "university": 4,
}

TYPE_COLORS = {
    "church": "Color(0.55, 0.42, 0.32, 1)",
    "cathedral": "Color(0.50, 0.38, 0.30, 1)",
    "tower": "Color(0.48, 0.44, 0.36, 1)",
    "school": "Color(0.40, 0.36, 0.30, 1)",
    "university": "Color(0.42, 0.38, 0.32, 1)",
    "hospital": "Color(0.44, 0.38, 0.34, 1)",
    "hotel": "Color(0.42, 0.36, 0.32, 1)",
    "commercial": "Color(0.38, 0.34, 0.30, 1)",
    "retail": "Color(0.36, 0.32, 0.28, 1)",
    "office": "Color(0.40, 0.36, 0.32, 1)",
    "industrial": "Color(0.32, 0.30, 0.26, 1)",
    "residential": "Color(0.40, 0.36, 0.30, 1)",
    "apartments": "Color(0.40, 0.35, 0.30, 1)",
    "house": "Color(0.42, 0.38, 0.33, 1)",
    "garage": "Color(0.32, 0.28, 0.24, 1)",
    "road": "Color(0.18, 0.17, 0.15, 1)",
    "water": "Color(0.04, 0.12, 0.22, 1)",
    "ground": "Color(0.18, 0.16, 0.13, 1)",
    "default": "Color(0.38, 0.35, 0.30, 1)",
}


def fetch_osm():
    import requests
    for url in OVERPASS_URLS:
        try:
            print(f"  Trying {url.split('/')[2]}...")
            r = requests.post(url, data={"data": QUERY}, timeout=45,
                              headers={"Content-Type": "application/x-www-form-urlencoded",
                                       "User-Agent": "Valdoria/0.2"})
            r.raise_for_status()
            return r.json()
        except Exception as e:
            print(f"    Failed: {e}")
            time.sleep(1)
    raise Exception("All endpoints failed")


def latlon_to_local(lat, lon):
    center_lat = (BBOX["south"] + BBOX["north"]) / 2
    center_lon = (BBOX["west"] + BBOX["east"]) / 2
    x = (lon - center_lon) * LAT_TO_METERS * math.cos(math.radians(center_lat))
    z = -(lat - center_lat) * LAT_TO_METERS
    return x, z


def get_height(tags):
    if not tags: return 3 * FLOOR_HEIGHT
    h = tags.get("height")
    if h:
        try: return float(str(h).replace("m","").strip())
        except: pass
    lv = tags.get("building:levels")
    if lv:
        try: return float(str(lv).split(";")[0].strip()) * FLOOR_HEIGHT
        except: pass
    bt = tags.get("building", "yes")
    return TYPE_HEIGHTS.get(bt, 3) * FLOOR_HEIGHT


def main():
    print("=" * 50)
    print(f"  OSM -> Godot .tres  |  {CITY_NAME.upper()}")
    print("=" * 50)

    # 1. Download OSM
    print("\n[1/3] Downloading OSM data...")
    try:
        data = fetch_osm()
    except Exception as e:
        print(f"  FAILED: {e}")
        return

    elements = data.get("elements", [])
    buildings = [e for e in elements if "building" in (e.get("tags") or {})]
    roads = [e for e in elements if "highway" in (e.get("tags") or {})]
    water = [e for e in elements if (e.get("tags") or {}).get("natural") == "water"]
    print(f"  Downloaded: {len(buildings)} buildings, {len(roads)} roads, {len(water)} water")

    # 2. Convert to building records
    print("\n[2/3] Converting building data...")
    building_lines = []
    for bld in buildings:
        coords = [(p["lat"], p["lon"]) for p in bld.get("geometry", [])]
        if len(coords) < 3:
            continue

        tags = bld.get("tags") or {}
        btype = tags.get("building", "default")
        height = get_height(tags)
        color_str = TYPE_COLORS.get(btype, TYPE_COLORS["default"])

        # Calcola AABB come box (per semplicita, prendi il bounding box del footprint)
        local_pts = [latlon_to_local(lat, lon) for lat, lon in coords]
        xs = [p[0] for p in local_pts]
        zs = [p[1] for p in local_pts]
        cx = (min(xs) + max(xs)) / 2
        cz = (min(zs) + max(zs)) / 2
        sx = (max(xs) - min(xs)) or 2.0
        sz = (max(zs) - min(zs)) or 2.0

        # Appiattisci edifici molto sottili
        if sx < 0.5 or sz < 0.5:
            continue

        building_lines.append(
            f'{{"pos": Vector3({cx:.2f}, {height/2:.2f}, {cz:.2f}), '
            f'"size": Vector3({sx:.2f}, {height:.2f}, {sz:.2f}), '
            f'"color": {color_str}, '
            f'"type": "{btype}"}}'
        )

    # 3. Export .tres
    print("\n[3/3] Exporting .tres resource...")
    tres_path = f"assets/real_world/{CITY_NAME}/{CITY_NAME}_buildings.tres"
    os.makedirs(os.path.dirname(tres_path), exist_ok=True)

    with open(tres_path, "w", encoding="utf-8") as f:
        f.write(f'[gd_resource type="Resource" script_class="OSMCityData" load_steps=2 format=3 uid="uid://{CITY_NAME}buildings"]\n\n')
        f.write(f'[ext_resource type="Script" path="res://scripts/real_world/OSMCityData.gd" id="1"]\n\n')
        f.write(f'[resource]\n')
        f.write(f'script = ExtResource("1")\n')
        f.write(f'city_name = "{CITY_NAME}"\n')
        f.write(f'city_display = "Bologna, Italia"\n')
        f.write(f'buildings_count = {len(building_lines)}\n')
        f.write(f'roads_count = {len(roads)}\n')
        f.write(f'buildings = [\n')
        for i, line in enumerate(building_lines):
            comma = "," if i < len(building_lines) - 1 else ""
            f.write(f'    {line}{comma}\n')
        f.write(f']\n')

        # Road data
        f.write(f'roads = [\n')
        road_count = 0
        for rd in roads:
            coords = [(p["lat"], p["lon"]) for p in rd.get("geometry", [])]
            if len(coords) < 2:
                continue
            local_pts = [latlon_to_local(lat, lon) for lat, lon in coords]
            pts_str = ", ".join(f"Vector2({x:.2f}, {z:.2f})" for x, z in local_pts)
            comma = "," if road_count < min(len(roads), 200) - 1 else ""
            f.write(f'    [PackedVector2Array([{pts_str}])]{comma}\n')
            road_count += 1
            if road_count >= 200:
                break
        f.write(f']\n')

    print(f"\n  OK: {tres_path}")
    print(f"  Buildings: {len(building_lines)}")
    print(f"  Roads: {min(road_count, 200)}")
    print(f"\n  Next: Godot carica il .tres e crea le mesh via RealCityController.")


if __name__ == "__main__":
    main()
