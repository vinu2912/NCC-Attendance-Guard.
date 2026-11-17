# NCC Face Recognition Service

A Python microservice that marks attendance from a photo. Staff take one photo of a cadet,
or of a whole platoon, and the service finds every face and works out which cadet it is.

## Model

| Stage | Model | Notes |
|---|---|---|
| Face detection | **RetinaFace** (InsightFace `buffalo_l`) | Finds faces of different sizes and angles in group photos |
| Alignment | 5-point landmarks | Straightens each face before it is recognised |
| Recognition | **ArcFace ResNet-50** (WebFace600K) | 512-d embeddings, about 99.8% on the LFW benchmark |
| Head pose | 3D 68-landmark model | Rejects faces turned too far to the side |

### How it stays accurate
- **Quality checks:** blurry, tiny, low-confidence or side-on faces are **rejected, not guessed**.
- **Several enrollment photos:** each cadet is enrolled with 3 or more photos (front and slight left/right).
  Matching uses both the average of those photos and the closest single photo.
- **Strict threshold + margin:** the best match must have cosine similarity ≥ 0.45 **and** beat the
  second-best cadet by ≥ 0.08. Otherwise the face is reported as `unknown`.
- **One cadet per face:** in a group photo, each cadet can match at most one face, so nobody is marked twice.
- **Optional filter:** pass `cadet_ids` to match only against one institute or batch, which cuts down mistakes.

All thresholds are in [`app/config.py`](app/config.py) and can be changed with environment variables.

## API

| Method | Path | Body | Purpose |
|---|---|---|---|
| GET | `/health` | – | Status + number of enrolled cadets |
| POST | `/enroll` | form: `cadet_id`, `name`, `images[]` | Register a cadet's face |
| GET | `/cadets` | – | List enrolled cadets |
| DELETE | `/cadets/{cadet_id}` | – | Remove a cadet's face data |
| POST | `/recognize` | form: `image`, optional `cadet_ids` | Identify all faces in a photo |

Example `/recognize` response:
```json
{
  "faces_detected": 3,
  "recognized_cadet_ids": ["101", "104"],
  "faces": [
    {"bbox": [120, 80, 210, 190], "det_score": 0.91, "status": "matched", "cadet_id": "101", "name": "Aarav Kulkarni", "similarity": 0.71},
    {"bbox": [300, 95, 380, 200], "det_score": 0.88, "status": "matched", "cadet_id": "104", "name": "Sneha Joshi", "similarity": 0.64},
    {"bbox": [520, 60, 560, 105], "det_score": 0.55, "status": "rejected", "reason": "low_detection_confidence"}
  ]
}
```

## How to run

```bash
cd face-recognition
python -m venv .venv
.venv\Scripts\activate          # Windows  (Linux/Mac: source .venv/bin/activate)
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```
The first start downloads the `buffalo_l` model (about 280 MB) to `~/.insightface`.
Interactive API docs: http://localhost:8000/docs

To run it with Docker instead:
```bash
docker build -t ncc-face .
docker run -p 8000:8000 -v ncc-face-data:/srv/data ncc-face
```

### Enroll cadets in bulk
Put the photos in folders named `<cadet_id>__<Name>` (use the same cadet IDs as the main database), then run:
```bash
python -m scripts.bulk_enroll path/to/photos
```

## Privacy
Face embeddings are biometric data. They are stored only in `data/`, which is git-ignored and never committed.
Get the cadets' consent before enrolling them.
