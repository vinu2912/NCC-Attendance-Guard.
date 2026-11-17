"""Face detection + embedding using InsightFace (RetinaFace + ArcFace).

Why this model: ArcFace (buffalo_l) is a widely used open-source face recognition model.
It reports about 99.8% verification accuracy on the LFW benchmark. Real-world accuracy
depends on lighting, camera quality and how many enrollment photos each cadet has.
"""
from dataclasses import dataclass
from typing import List, Optional

import cv2
import numpy as np
from insightface.app import FaceAnalysis

from . import config


@dataclass
class DetectedFace:
    bbox: List[int]                    # [x1, y1, x2, y2]
    det_score: float
    embedding: Optional[np.ndarray]    # 512-d, L2-normalised (None if rejected)
    rejected_reason: Optional[str] = None


class FaceEngine:
    def __init__(self) -> None:
        providers = (["CUDAExecutionProvider", "CPUExecutionProvider"]
                     if config.USE_GPU else ["CPUExecutionProvider"])
        self.app = FaceAnalysis(name=config.MODEL_NAME, providers=providers)
        self.app.prepare(ctx_id=0 if config.USE_GPU else -1,
                         det_size=(config.DET_SIZE, config.DET_SIZE))

    @staticmethod
    def decode_image(data: bytes) -> np.ndarray:
        img = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("Could not decode image")
        return img

    @staticmethod
    def _sharpness(img: np.ndarray, bbox: List[int]) -> float:
        x1, y1, x2, y2 = bbox
        crop = img[max(y1, 0):max(y2, 0), max(x1, 0):max(x2, 0)]
        if crop.size == 0:
            return 0.0
        gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
        return float(cv2.Laplacian(gray, cv2.CV_64F).var())

    def _quality_issue(self, img: np.ndarray, face) -> Optional[str]:
        bbox = face.bbox.astype(int).tolist()
        w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        if face.det_score < config.MIN_DET_SCORE:
            return "low_detection_confidence"
        if min(w, h) < config.MIN_FACE_PX:
            return "face_too_small"
        pose = getattr(face, "pose", None)
        if pose is not None and abs(float(pose[1])) > config.MAX_YAW_DEG:
            return "face_turned_away"
        if self._sharpness(img, bbox) < config.MIN_SHARPNESS:
            return "too_blurry"
        return None

    def detect(self, img: np.ndarray) -> List[DetectedFace]:
        results = []
        for f in self.app.get(img):
            reason = self._quality_issue(img, f)
            results.append(DetectedFace(
                bbox=f.bbox.astype(int).tolist(),
                det_score=float(f.det_score),
                embedding=None if reason else f.normed_embedding.astype(np.float32),
                rejected_reason=reason,
            ))
        return results

    def single_face_embedding(self, img: np.ndarray) -> np.ndarray:
        """Used for enrollment: the photo must contain exactly one good-quality face."""
        faces = self.detect(img)
        if len(faces) != 1:
            raise ValueError(f"Expected exactly 1 face, found {len(faces)}")
        if faces[0].embedding is None:
            raise ValueError(f"Face rejected: {faces[0].rejected_reason}")
        return faces[0].embedding
