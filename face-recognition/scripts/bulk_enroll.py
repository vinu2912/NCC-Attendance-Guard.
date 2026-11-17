"""Bulk-enroll cadets from a folder of photos.

Folder layout (one sub-folder per cadet, named  <cadet_id>__<Name>):
    photos/
      101__Aarav Kulkarni/  front.jpg  left.jpg  right.jpg
      102__Diya Patil/      1.jpg 2.jpg 3.jpg

Usage:
    python -m scripts.bulk_enroll path/to/photos
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.face_engine import FaceEngine  # noqa: E402
from app.store import EmbeddingStore    # noqa: E402

IMG_EXT = {".jpg", ".jpeg", ".png", ".webp"}


def main(root: str) -> None:
    engine, store = FaceEngine(), EmbeddingStore()
    for folder in sorted(os.listdir(root)):
        path = os.path.join(root, folder)
        if not os.path.isdir(path) or "__" not in folder:
            continue
        cadet_id, name = folder.split("__", 1)
        embs = []
        for fn in os.listdir(path):
            if os.path.splitext(fn)[1].lower() not in IMG_EXT:
                continue
            with open(os.path.join(path, fn), "rb") as f:
                try:
                    embs.append(engine.single_face_embedding(engine.decode_image(f.read())))
                except ValueError as e:
                    print(f"  skip {folder}/{fn}: {e}")
        if embs:
            total = store.enroll(cadet_id, name, embs)
            print(f"[ok] {cadet_id} {name}: {len(embs)} photos ({total} total)")
        else:
            print(f"[!!] {cadet_id} {name}: no usable photos")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: python -m scripts.bulk_enroll <photos_folder>")
    main(sys.argv[1])
