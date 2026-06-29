#!/usr/bin/env python3
"""Download detailed Paris building volumes for the real-city renderer.

Source dataset: Paris Data "Volumes bâtis" (ODbL).
The raw records are normalized into a compact JSON that Godot can parse at
runtime without needing a GIS stack.
"""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "data" / "sources" / "gis"
OUT_PATH = OUT_DIR / "paris_volumesbatis_ile_cite.compact.json"

DATASET_URL = "https://opendata.paris.fr/api/explore/v2.1/catalog/datasets/volumesbatisparis/records"
BBOX = (48.8588, 2.3412, 48.8512, 2.3548)  # north, west, south, east
PAGE_SIZE = 100


def fetch_page(offset: int) -> dict:
    where = "in_bbox(geom, %.4f, %.4f, %.4f, %.4f)" % BBOX
    params = {
        "limit": str(PAGE_SIZE),
        "offset": str(offset),
        "where": where,
        "order_by": "st_area_shape desc",
    }
    url = DATASET_URL + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": "ValdoriaPrototype/0.1"})
    with urllib.request.urlopen(req, timeout=60) as response:
        return json.loads(response.read().decode("utf-8"))


def rings_from_record(record: dict) -> list[list[list[float]]]:
    geom = (record.get("geom") or {}).get("geometry") or {}
    coords = geom.get("coordinates") or []
    if geom.get("type") == "Polygon":
        rings = coords
    elif geom.get("type") == "MultiPolygon":
        rings = [ring for polygon in coords for ring in polygon]
    else:
        return []

    normalized: list[list[list[float]]] = []
    for ring in rings:
        pts: list[list[float]] = []
        for coord in ring:
            if len(coord) < 2:
                continue
            lon = float(coord[0])
            lat = float(coord[1])
            pts.append([lat, lon])
        if len(pts) >= 4:
            normalized.append(pts)
    return normalized


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    features: list[dict] = []
    total = None
    offset = 0
    while total is None or offset < total:
        data = fetch_page(offset)
        total = int(data.get("total_count", 0))
        rows = data.get("results", [])
        if not rows:
            break
        for record in rows:
            rings = rings_from_record(record)
            if not rings:
                continue
            features.append(
                {
                    "id": record.get("n_sq_vb") or record.get("objectid"),
                    "rings": rings,
                    "levels": record.get("h_et_max") or record.get("nb_pl") or 1,
                    "height_label": record.get("l_plan_h") or "",
                    "kind": record.get("l_nat_b") or "",
                    "area": record.get("st_area_shape") or record.get("m2") or 0,
                    "updated": record.get("d_maj") or "",
                }
            )
        offset += len(rows)
        print("Fetched %d / %d Paris building-volume records" % (offset, total))
        time.sleep(0.05)

    payload = {
        "source": "Paris Data - Volumes bâtis",
        "dataset": "volumesbatisparis",
        "license": "ODbL",
        "bbox": [48.8512, 2.3412, 48.8588, 2.3548],
        "feature_count": len(features),
        "features": features,
    }
    OUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    print("Wrote %s (%d features)" % (OUT_PATH.relative_to(ROOT), len(features)))


if __name__ == "__main__":
    main()
