"""Tunable settings. Override any of them with environment variables."""
import os

# InsightFace model pack: RetinaFace detector + ArcFace (ResNet-50, WebFace600K) embeddings.
MODEL_NAME = os.getenv("FACE_MODEL", "buffalo_l")
DET_SIZE = int(os.getenv("FACE_DET_SIZE", "640"))
USE_GPU = os.getenv("FACE_USE_GPU", "0") == "1"

# Cosine similarity needed to accept a match (ArcFace embeddings, L2-normalised).
# 0.45 is strict: very few false matches. Lower to 0.40 if real cadets get missed.
MATCH_THRESHOLD = float(os.getenv("FACE_MATCH_THRESHOLD", "0.45"))
# Best match must beat the 2nd-best cadet by this much, otherwise it is treated as ambiguous.
MATCH_MARGIN = float(os.getenv("FACE_MATCH_MARGIN", "0.08"))

# Quality gates: faces failing these are rejected rather than guessed.
MIN_DET_SCORE = float(os.getenv("FACE_MIN_DET_SCORE", "0.60"))
MIN_FACE_PX = int(os.getenv("FACE_MIN_FACE_PX", "64"))       # min face width/height in pixels
MAX_YAW_DEG = float(os.getenv("FACE_MAX_YAW", "35"))         # head turned too far sideways
MIN_SHARPNESS = float(os.getenv("FACE_MIN_SHARPNESS", "40"))  # Laplacian variance (blur check)

# Enrollment: number of photos needed per cadet (more photos = better accuracy).
MIN_ENROLL_IMAGES = int(os.getenv("FACE_MIN_ENROLL_IMAGES", "3"))

DATA_DIR = os.getenv("FACE_DATA_DIR", os.path.join(os.path.dirname(__file__), "..", "data"))
