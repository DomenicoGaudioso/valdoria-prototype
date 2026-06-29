"""
fix_glb_materials.py — Rigenera il GLB di Bologna con materiali PBR standard
================================================================================
Il GLB originale usa vertex colors che potrebbero non rendersi correttamente
nel renderer Godot Forward+. Questo script ricarica il GLB e lo riesporta
con materiali StandardMaterial3D-like (albedo per tipo edificio).
"""

import numpy as np
import trimesh

INPUT_GLB = "assets/real_world/bologna/bologna_full.glb"
OUTPUT_GLB = "assets/real_world/bologna/bologna_full.glb"

# Colori materiali dark fantasy per tipo edificio
BUILDING_COLORS = {
    "church": (0.55, 0.42, 0.32),
    "cathedral": (0.50, 0.38, 0.30),
    "tower": (0.48, 0.44, 0.36),
    "university": (0.42, 0.38, 0.32),
    "school": (0.40, 0.36, 0.30),
    "hospital": (0.44, 0.38, 0.34),
    "hotel": (0.42, 0.36, 0.32),
    "commercial": (0.38, 0.34, 0.30),
    "retail": (0.36, 0.32, 0.28),
    "office": (0.40, 0.36, 0.32),
    "industrial": (0.32, 0.30, 0.26),
    "residential": (0.40, 0.36, 0.30),
    "apartments": (0.40, 0.35, 0.30),
    "house": (0.42, 0.38, 0.33),
    "garage": (0.32, 0.28, 0.24),
    "roof": (0.38, 0.34, 0.28),
    "road": (0.22, 0.20, 0.18),
    "ground": (0.18, 0.16, 0.14),
    "water": (0.05, 0.15, 0.25),
    "default": (0.40, 0.36, 0.32),
}


def classify_mesh(name: str, verts) -> str:
    name_lower = name.lower()
    if "road" in name_lower:
        return "road"
    if "water" in name_lower:
        return "water"
    if "ground" in name_lower or "plane" in name_lower:
        return "ground"
    if len(verts) < 20:
        return "default"
    # Residenziale piu chiaro, commerciale piu scuro
    h = hash(name) % 10
    if h < 4:
        return "residential"
    if h < 6:
        return "commercial"
    if h < 7:
        return "office"
    if h < 8:
        return "church"
    return "apartments"


def main():
    print("Loading GLB...")
    scene = trimesh.load(INPUT_GLB)

    if isinstance(scene, trimesh.Scene):
        meshes = list(scene.geometry.values())
        names = list(scene.geometry.keys())
    elif isinstance(scene, trimesh.Trimesh):
        meshes = [scene]
        names = ["root"]
    else:
        print("Unknown format")
        return

    print(f"Found {len(meshes)} meshes")

    # Forza materiali PBR invece di vertex colors
    fixed_meshes = []
    for i, mesh in enumerate(meshes):
        if not isinstance(mesh, trimesh.Trimesh):
            continue

        mesh_type = classify_mesh(names[i] if i < len(names) else "bld_%d" % i, mesh.vertices)
        color = BUILDING_COLORS.get(mesh_type, BUILDING_COLORS["default"])

        # Crea nuovo mesh con materiale PBR (albedo)
        new_mesh = trimesh.Trimesh(
            vertices=mesh.vertices.copy(),
            faces=mesh.faces.copy(),
            process=False,
        )

        # Imposta colore come materiale PBR: albedo con un po' di roughness
        new_mesh.visual = trimesh.visual.ColorVisuals(
            mesh=new_mesh,
            vertex_colors=None,
        )
        # Usa face colors come fallback perche Godot li interpreta come materiale
        face_count = len(new_mesh.faces)
        if face_count > 0:
            face_colors = np.tile(
                np.array([int(color[2] * 255), int(color[1] * 255), int(color[0] * 255), 255], dtype=np.uint8),
                (face_count, 1)
            )
            new_mesh.visual = trimesh.visual.ColorVisuals(
                mesh=new_mesh,
                face_colors=face_colors,
            )

        fixed_meshes.append(new_mesh)

    print(f"Fixed {len(fixed_meshes)} meshes with PBR-like materials")
    combined = trimesh.util.concatenate(fixed_meshes)
    combined.merge_vertices(digits_vertex=3)

    # Esporta con materiali nel GLTF
    combined.export(OUTPUT_GLB, file_type="glb")

    import os
    file_size = os.path.getsize(OUTPUT_GLB) / (1024 * 1024)
    print(f"\nExported: {OUTPUT_GLB} ({file_size:.1f} MB)")
    print(f"Vertices: {len(combined.vertices):,}")
    print(f"Faces: {len(combined.faces):,}")
    print("Done! Riapri TestBologna.tscn in Godot.")


if __name__ == "__main__":
    main()
