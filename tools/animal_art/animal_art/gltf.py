"""Writes a model as glTF 2.0 (.glb), the game's interchange format (docs/ASSETS.md): named parts, each one mesh with
positions, normals and vertex colours, under one plain material. Y is up; 1 unit = 1 tile. The same input always
gives the same file."""
import json
import struct

import numpy as np

MATERIAL = {"name": "paint", "pbrMetallicRoughness": {"baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0.0, "roughnessFactor": 0.9}}


def write_glb(path, parts):
    """`parts`: [(name, V (n,3), N (n,3), C (n,4), T (m,3))], each written as a child node of the root with that name
    (a state part is named `when_<state>_<value>`). Colours are RGBA floats; alpha 0 marks produce (crops)."""
    blob = bytearray(); views, accessors, meshes, nodes = [], [], [], []

    def add(data, comp, kind, target, minmax=False):
        data = np.ascontiguousarray(data)
        while len(blob) % 4:
            blob.append(0)
        views.append({"buffer": 0, "byteOffset": len(blob), "byteLength": data.nbytes, "target": target})
        blob.extend(data.tobytes())
        acc = {"bufferView": len(views) - 1, "componentType": comp, "count": int(len(data) if kind != "SCALAR" else data.size), "type": kind}
        if minmax:
            acc["min"] = [float(v) for v in data.min(0)]; acc["max"] = [float(v) for v in data.max(0)]
        accessors.append(acc)
        return len(accessors) - 1

    for name, V, N, C, T in parts:
        prim = {"attributes": {"POSITION": add(np.asarray(V, np.float32), 5126, "VEC3", 34962, True),
                               "NORMAL": add(np.asarray(N, np.float32), 5126, "VEC3", 34962),
                               "COLOR_0": add(np.asarray(C, np.float32), 5126, "VEC4", 34962)},
                "indices": add(np.asarray(T, np.uint32).reshape(-1), 5125, "SCALAR", 34963), "material": 0}
        meshes.append({"name": name, "primitives": [prim]})
        nodes.append({"name": name, "mesh": len(meshes) - 1})
    root = {"name": "root", "children": list(range(len(nodes)))}
    doc = {"asset": {"version": "2.0", "generator": "animal_art"}, "scene": 0, "scenes": [{"nodes": [len(nodes)]}],
           "nodes": nodes + [root], "meshes": meshes, "materials": [MATERIAL], "accessors": accessors, "bufferViews": views,
           "buffers": [{"byteLength": len(blob)}]}
    while len(blob) % 4:
        blob.append(0)
    text = json.dumps(doc, separators=(",", ":"), sort_keys=True).encode()
    text += b" " * (-len(text) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(text) + 8 + len(blob)))
        f.write(struct.pack("<I4s", len(text), b"JSON")); f.write(text)
        f.write(struct.pack("<I4s", len(blob), b"BIN\0")); f.write(bytes(blob))
