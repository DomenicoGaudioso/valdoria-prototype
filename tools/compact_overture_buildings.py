#!/usr/bin/env python3
"""Compact Overture building/building_part GeoJSON into Valdoria detail JSON."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
SRC_DIR = ROOT / "data" / "sources" / "gis"

CITIES = {
    "roma_centro": [41.8848, 12.4738, 41.9048, 12.5038],
    "venezia_rialto": [45.4313, 12.3250, 45.4438, 12.3480],
    "berlin_mitte_3d": [52.5132, 13.3705, 52.5238, 13.3908],
    "tokyo_shibuya": [35.6572, 139.6962, 35.6656, 139.7108],
}


def polygon_area(points: list[list[float]]) -> float:
    area = 0.0
    for i, a in enumerate(points):
        b = points[(i + 1) % len(points)]
        area += a[1] * b[0] - b[1] * a[0]
    return abs(area) * 0.5


def iter_outer_rings(geometry: dict) -> Iterable[list[list[float]]]:
    geom_type = geometry.get("type")
    coords = geometry.get("coordinates") or []
    if geom_type == "Polygon":
        polygons = [coords]
    elif geom_type == "MultiPolygon":
        polygons = coords
    else:
        return
    for polygon in polygons:
        if not polygon:
            continue
        outer = polygon[0]
        ring: list[list[float]] = []
        for coord in outer:
            if len(coord) < 2:
                continue
            lon = float(coord[0])
            lat = float(coord[1])
            ring.append([lat, lon])
        if len(ring) >= 4:
            yield ring


def load_features(city_id: str, kind: str) -> list[dict]:
    path = SRC_DIR / f"{city_id}_overture_{kind}.geojson"
    if not path.exists():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    features: list[dict] = []
    for feature in data.get("features", []):
        props = feature.get("properties") or {}
        geometry = feature.get("geometry") or {}
        if props.get("is_underground"):
            continue
        for idx, ring in enumerate(iter_outer_rings(geometry)):
            height = props.get("height")
            floors = props.get("num_floors")
            if height is None and floors is not None:
                try:
                    height = float(floors) * 3.2
                except (TypeError, ValueError):
                    height = None
            features.append(
                {
                    "id": feature.get("id") or f"{city_id}_{kind}_{len(features)}_{idx}",
                    "rings": [ring],
                    "height": height,
                    "levels": floors,
                    "kind": kind,
                    "subtype": props.get("subtype") or "",
                    "has_parts": bool(props.get("has_parts")),
                    "area": polygon_area(ring),
                }
            )
    return features


def compact_city(city_id: str, bbox: list[float]) -> None:
    parts = load_features(city_id, "building_part")
    buildings = load_features(city_id, "building")
    if parts:
        buildings = [feature for feature in buildings if not feature.get("has_parts")]
    features = parts + buildings
    features.sort(key=lambda item: float(item.get("area") or 0.0), reverse=True)
    out = {
        "source": "Overture Maps buildings/building_part",
        "dataset": "overturemaps",
        "license": "ODbL-1.0",
        "bbox": bbox,
        "feature_count": len(features),
        "features": features,
    }
    out_path = SRC_DIR / f"{city_id}_overture_buildings.compact.json"
    out_path.write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("Wrote %s (%d features)" % (out_path.relative_to(ROOT), len(features)))


def main() -> None:
    for city_id, bbox in CITIES.items():
        compact_city(city_id, bbox)


if __name__ == "__main__":
    main()
