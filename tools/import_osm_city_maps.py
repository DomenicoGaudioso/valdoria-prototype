#!/usr/bin/env python3
"""Generate Valdoria city maps from OpenStreetMap/Overpass data.

The output format matches data/maps/*_data.gd:
  static func get_data() -> Dictionary:
      return {"width": int, "height": int, "background": [...], "object": [...]}

This is intentionally stylized: OSM roads, water, parks, buildings and POIs
are rasterized into the existing FLARE isometric tile IDs used by GameBootstrap.
Raw Overpass JSON is stored under data/sources/osm for attribution/debugging.
"""

from __future__ import annotations

import json
import math
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "data" / "maps"
SRC_DIR = ROOT / "data" / "sources" / "osm"
OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass.osm.ch/api/interpreter",
]


CITIES = [
    {
        "id": "roma_centro",
        "title": "Roma Centro",
        "bbox": (41.8848, 12.4738, 41.9048, 12.5038),
        "spawn": (50, 54),
        "style": "ancient",
    },
    {
        "id": "venezia_rialto",
        "title": "Venezia Rialto",
        "bbox": (45.4313, 12.3250, 45.4438, 12.3480),
        "spawn": (52, 48),
        "style": "water_city",
    },
    {
        "id": "parigi_cite",
        "title": "Parigi Ile de la Cite",
        "bbox": (48.8512, 2.3412, 48.8588, 2.3548),
        "spawn": (49, 50),
        "style": "gothic",
    },
    {
        "id": "berlin_mitte_3d",
        "title": "Berlino Mitte 3D",
        "bbox": (52.5132, 13.3705, 52.5238, 13.3908),
        "spawn": (47, 53),
        "style": "urban_3d",
    },
    {
        "id": "tokyo_shibuya",
        "title": "Tokyo Shibuya",
        "bbox": (35.6572, 139.6962, 35.6656, 139.7108),
        "spawn": (52, 52),
        "style": "dense_3d",
    },
]


W = 100
H = 100
MARGIN = 5

GRASS = [16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31]
ROAD = [32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 47]
WATER = [176, 177, 178, 179, 180, 181, 182, 183, 184, 185, 186, 187]
STRUCTURES = list(range(208, 240))
TREES = list(range(240, 264))
TWO_BY_TWO = list(range(264, 296))


def query_for_bbox(bbox: tuple[float, float, float, float]) -> str:
    south, west, north, east = bbox
    filters = f"""
    (
      way["highway"]({south},{west},{north},{east});
      way["building"]({south},{west},{north},{east});
      way["natural"="water"]({south},{west},{north},{east});
      way["waterway"]({south},{west},{north},{east});
      way["landuse"~"grass|forest|meadow|recreation_ground|cemetery|residential|commercial|industrial"]({south},{west},{north},{east});
      way["leisure"~"park|garden|pitch|common"]({south},{west},{north},{east});
      way["amenity"~"place_of_worship|university|school|marketplace|fountain"]({south},{west},{north},{east});
      way["historic"]({south},{west},{north},{east});
      way["tourism"~"attraction|museum|viewpoint|hotel"]({south},{west},{north},{east});
      node["tourism"~"attraction|museum|viewpoint"]({south},{west},{north},{east});
      node["historic"]({south},{west},{north},{east});
    );
    out tags geom;
    """
    return "[out:json][timeout:90];" + filters


def fetch_overpass(city: dict) -> dict:
    query = query_for_bbox(city["bbox"])
    data = urllib.parse.urlencode({"data": query}).encode("utf-8")
    errors: list[str] = []
    for url in OVERPASS_URLS:
        try:
            req = urllib.request.Request(
                url,
                data=data,
                headers={
                    "User-Agent": "ValdoriaPrototype/0.1 OSM importer",
                    "Content-Type": "application/x-www-form-urlencoded",
                },
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=120) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except (urllib.error.URLError, TimeoutError, json.JSONDecodeError) as exc:
            errors.append(f"{url}: {exc}")
            time.sleep(1.0)
    raise RuntimeError("Overpass failed for %s:\n%s" % (city["id"], "\n".join(errors)))


def project(lat: float, lon: float, bbox: tuple[float, float, float, float]) -> tuple[int, int]:
    south, west, north, east = bbox
    x = (lon - west) / max(east - west, 1e-9)
    y = (north - lat) / max(north - south, 1e-9)
    gx = int(round(MARGIN + x * (W - MARGIN * 2 - 1)))
    gy = int(round(MARGIN + y * (H - MARGIN * 2 - 1)))
    return max(0, min(W - 1, gx)), max(0, min(H - 1, gy))


def draw_cell(grid: list[list[int]], x: int, y: int, gid: int, radius: int = 0) -> None:
    for yy in range(y - radius, y + radius + 1):
        for xx in range(x - radius, x + radius + 1):
            if 0 <= xx < W and 0 <= yy < H and abs(xx - x) + abs(yy - y) <= radius + 1:
                grid[yy][xx] = gid


def draw_line(grid: list[list[int]], a: tuple[int, int], b: tuple[int, int], gid: int, radius: int = 0) -> None:
    x0, y0 = a
    x1, y1 = b
    dx = abs(x1 - x0)
    dy = -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        draw_cell(grid, x0, y0, gid, radius)
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def point_in_poly(px: int, py: int, poly: list[tuple[int, int]]) -> bool:
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        crosses = (yi > py) != (yj > py)
        if crosses:
            x_intersect = (xj - xi) * (py - yi) / max(yj - yi, 1e-9) + xi
            if px < x_intersect:
                inside = not inside
        j = i
    return inside


def fill_poly(grid: list[list[int]], poly: list[tuple[int, int]], gid: int, max_cells: int = 900) -> int:
    if len(poly) < 3:
        return 0
    min_x = max(0, min(p[0] for p in poly))
    max_x = min(W - 1, max(p[0] for p in poly))
    min_y = max(0, min(p[1] for p in poly))
    max_y = min(H - 1, max(p[1] for p in poly))
    if (max_x - min_x + 1) * (max_y - min_y + 1) > max_cells:
        return 0
    count = 0
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            if point_in_poly(x, y, poly):
                grid[y][x] = gid
                count += 1
    return count


def element_geometry(element: dict, bbox: tuple[float, float, float, float]) -> list[tuple[int, int]]:
    if "geometry" not in element:
        if "lat" in element and "lon" in element:
            return [project(float(element["lat"]), float(element["lon"]), bbox)]
        return []
    pts: list[tuple[int, int]] = []
    for pt in element["geometry"]:
        if "lat" in pt and "lon" in pt:
            cell = project(float(pt["lat"]), float(pt["lon"]), bbox)
            if not pts or pts[-1] != cell:
                pts.append(cell)
    return pts


def classify(tags: dict) -> str:
    if "building" in tags:
        return "building"
    if tags.get("natural") == "water" or "waterway" in tags:
        return "water"
    if tags.get("leisure") in {"park", "garden", "common", "pitch"}:
        return "park"
    if tags.get("landuse") in {"grass", "forest", "meadow", "recreation_ground", "cemetery"}:
        return "park"
    if "highway" in tags:
        return "road"
    if "historic" in tags or tags.get("tourism") in {"attraction", "museum", "viewpoint"}:
        return "poi"
    if tags.get("amenity") in {"place_of_worship", "university", "school", "marketplace", "fountain"}:
        return "poi"
    return "other"


def road_radius(highway: str) -> int:
    if highway in {"motorway", "trunk", "primary", "secondary"}:
        return 2
    if highway in {"tertiary", "unclassified", "residential"}:
        return 1
    return 0


def building_gid(tags: dict, style: str, x: int, y: int) -> int:
    levels = tags.get("building:levels") or tags.get("levels")
    height = tags.get("height")
    tall = style in {"urban_3d", "dense_3d"}
    try:
        tall = tall or (levels is not None and float(str(levels).split(";")[0]) >= 4)
    except ValueError:
        pass
    try:
        tall = tall or (height is not None and float(str(height).replace("m", "")) >= 18)
    except ValueError:
        pass
    source = STRUCTURES if not tall else TWO_BY_TWO
    return source[(x * 7 + y * 13) % len(source)]


def generate_city(city: dict, osm: dict) -> dict:
    background = [[GRASS[(x * 5 + y * 3) % len(GRASS)] for x in range(W)] for y in range(H)]
    objects = [[0 for _x in range(W)] for _y in range(H)]
    bbox = city["bbox"]
    style = city["style"]

    # Stable processing order: large terrain first, roads next, buildings/POI on top.
    buckets = {"park": [], "water": [], "road": [], "building": [], "poi": []}
    for element in osm.get("elements", []):
        tags = element.get("tags", {})
        cls = classify(tags)
        if cls in buckets:
            buckets[cls].append(element)

    for element in buckets["park"]:
        pts = element_geometry(element, bbox)
        if len(pts) >= 3:
            fill_poly(background, pts, GRASS[(len(pts) * 3) % len(GRASS)])
            for i, (x, y) in enumerate(pts[:: max(1, len(pts) // 6)]):
                if (x + y + i) % 2 == 0:
                    objects[y][x] = TREES[(x * 3 + y * 5) % len(TREES)]

    for element in buckets["water"]:
        pts = element_geometry(element, bbox)
        if len(pts) >= 3 and pts[0] == pts[-1]:
            fill_poly(background, pts, WATER[(len(pts) * 5) % len(WATER)], max_cells=2500)
        elif len(pts) >= 2:
            gid = WATER[(len(pts) * 5) % len(WATER)]
            for a, b in zip(pts, pts[1:]):
                draw_line(background, a, b, gid, radius=1)

    for element in buckets["road"]:
        tags = element.get("tags", {})
        pts = element_geometry(element, bbox)
        if len(pts) < 2:
            continue
        highway = tags.get("highway", "road")
        gid = ROAD[(len(highway) + len(pts)) % len(ROAD)]
        radius = road_radius(highway)
        for a, b in zip(pts, pts[1:]):
            draw_line(background, a, b, gid, radius=radius)

    for element in buckets["building"]:
        tags = element.get("tags", {})
        pts = element_geometry(element, bbox)
        if len(pts) < 3:
            continue
        cx = int(round(sum(p[0] for p in pts) / len(pts)))
        cy = int(round(sum(p[1] for p in pts) / len(pts)))
        if 0 <= cx < W and 0 <= cy < H:
            gid = building_gid(tags, style, cx, cy)
            fill_poly(objects, pts, gid, max_cells=80 if style != "dense_3d" else 120)
            if objects[cy][cx] == 0:
                objects[cy][cx] = gid

    for element in buckets["poi"]:
        pts = element_geometry(element, bbox)
        if not pts:
            continue
        x = int(round(sum(p[0] for p in pts) / len(pts)))
        y = int(round(sum(p[1] for p in pts) / len(pts)))
        if 0 <= x < W and 0 <= y < H:
            objects[y][x] = STRUCTURES[(x * 11 + y * 17) % len(STRUCTURES)]
            draw_cell(background, x, y, ROAD[(x + y) % len(ROAD)], radius=1)

    # Add a readable city spine if the real data has sparse roads in a bbox.
    road_cells = sum(1 for row in background for gid in row if gid in ROAD)
    if road_cells < 260:
        for i in range(12, 88):
            draw_cell(background, i, 50 + int(math.sin(i / 8.0) * 7), ROAD[i % len(ROAD)], radius=1)
            draw_cell(background, 50 + int(math.cos(i / 9.0) * 6), i, ROAD[(i + 4) % len(ROAD)], radius=1)

    return {"width": W, "height": H, "background": background, "object": objects}


def gd_array(rows: list[list[int]], indent: str = "            ") -> str:
    return ",\n".join(indent + "[" + ",".join(str(v) for v in row) + "]" for row in rows)


def write_gd(city: dict, data: dict, osm_count: int) -> None:
    path = OUT_DIR / f"{city['id']}_data.gd"
    text = (
        "# Generated by import_osm_city_maps.py\n"
        f"# Source: OpenStreetMap / Overpass API, elements: {osm_count}\n"
        f"# Area: {city['title']}\n"
        "static func get_data() -> Dictionary:\n"
        "    return {\n"
        f"        \"width\": {data['width']},\n"
        f"        \"height\": {data['height']},\n"
        "        \"background\": [\n"
        + gd_array(data["background"])
        + "\n        ],\n"
        "        \"object\": [\n"
        + gd_array(data["object"])
        + "\n        ]\n"
        "    }\n"
    )
    path.write_text(text, encoding="utf-8")
    print(f"Wrote {path.relative_to(ROOT)}")


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    SRC_DIR.mkdir(parents=True, exist_ok=True)
    for city in CITIES:
        src_path = SRC_DIR / f"{city['id']}.overpass.json"
        if src_path.exists():
            osm = json.loads(src_path.read_text(encoding="utf-8"))
            print(f"Using cached {src_path.relative_to(ROOT)}")
        else:
            print(f"Fetching {city['title']} from Overpass...")
            osm = fetch_overpass(city)
            src_path.write_text(json.dumps(osm, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"Saved {src_path.relative_to(ROOT)}")
        data = generate_city(city, osm)
        write_gd(city, data, len(osm.get("elements", [])))


if __name__ == "__main__":
    main()
