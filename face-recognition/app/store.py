"""Stores cadet face embeddings on disk and matches new faces against them.

Each cadet keeps all enrollment embeddings plus a normalised mean (centroid).
A face is scored against every cadet with the centroid and the best single sample,
which handles cadets photographed with and without caps, glasses and so on.
"""
import json
import os
import threading
from typing import Dict, List, Optional, Tuple

import numpy as np

from . import config


def _normalise(v: np.ndarray) -> np.ndarray:
    return v / (np.linalg.norm(v) + 1e-12)


class EmbeddingStore:
    def __init__(self, data_dir: str = config.DATA_DIR) -> None:
        self.data_dir = os.path.abspath(data_dir)
        os.makedirs(self.data_dir, exist_ok=True)
        self.meta_path = os.path.join(self.data_dir, "cadets.json")
        self.emb_path = os.path.join(self.data_dir, "embeddings.npz")
        self.lock = threading.Lock()
        self.meta: Dict[str, dict] = {}
        self.samples: Dict[str, np.ndarray] = {}
        self._load()

    # ---------- persistence ----------
    def _load(self) -> None:
        if os.path.exists(self.meta_path):
            with open(self.meta_path, encoding="utf-8") as f:
                self.meta = json.load(f)
        if os.path.exists(self.emb_path):
            data = np.load(self.emb_path)
            self.samples = {k: data[k] for k in data.files}

    def _save(self) -> None:
        with open(self.meta_path, "w", encoding="utf-8") as f:
            json.dump(self.meta, f, indent=2)
        np.savez_compressed(self.emb_path, **self.samples)

    # ---------- enrollment ----------
    def enroll(self, cadet_id: str, name: str, embeddings: List[np.ndarray]) -> int:
        with self.lock:
            new = np.stack(embeddings)
            old = self.samples.get(cadet_id)
            self.samples[cadet_id] = new if old is None else np.vstack([old, new])
            self.meta[cadet_id] = {"name": name, "samples": int(self.samples[cadet_id].shape[0])}
            self._save()
            return self.meta[cadet_id]["samples"]

    def delete(self, cadet_id: str) -> bool:
        with self.lock:
            existed = self.meta.pop(cadet_id, None) is not None
            self.samples.pop(cadet_id, None)
            self._save()
            return existed

    def list(self) -> Dict[str, dict]:
        return dict(self.meta)

    # ---------- matching ----------
    def _scores(self, emb: np.ndarray, allowed: Optional[set]) -> List[Tuple[str, float]]:
        scores = []
        for cid, s in self.samples.items():
            if allowed is not None and cid not in allowed:
                continue
            centroid = _normalise(s.mean(axis=0))
            score = max(float(centroid @ emb), float((s @ emb).max()))
            scores.append((cid, score))
        scores.sort(key=lambda x: x[1], reverse=True)
        return scores

    def match_many(self, embeddings: List[np.ndarray],
                   allowed: Optional[set] = None) -> List[Optional[Tuple[str, float]]]:
        """Match several faces from one photo. Each cadet can be assigned to only one face
        (greedy, highest similarity first), so the same person is never marked twice."""
        candidates = []  # (score, face_idx, cadet_id)
        ambiguous = set()
        for i, emb in enumerate(embeddings):
            ranked = self._scores(emb, allowed)
            if not ranked or ranked[0][1] < config.MATCH_THRESHOLD:
                continue
            if len(ranked) > 1 and ranked[0][1] - ranked[1][1] < config.MATCH_MARGIN:
                ambiguous.add(i)
                continue
            for cid, sc in ranked:
                if sc >= config.MATCH_THRESHOLD:
                    candidates.append((sc, i, cid))

        result: List[Optional[Tuple[str, float]]] = [None] * len(embeddings)
        used_cadets = set()
        for sc, i, cid in sorted(candidates, reverse=True):
            if result[i] is None and cid not in used_cadets and i not in ambiguous:
                result[i] = (cid, sc)
                used_cadets.add(cid)
        return result
