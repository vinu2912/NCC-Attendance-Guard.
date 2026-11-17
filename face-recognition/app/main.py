"""NCC Face Recognition Service (FastAPI).

Endpoints
  GET    /health                 service + model status
  POST   /enroll                 register a cadet's face (3+ photos recommended)
  GET    /cadets                 list enrolled cadets
  DELETE /cadets/{cadet_id}      remove a cadet's face data
  POST   /recognize              detect + identify every face in a photo (group photos OK)

Run:  uvicorn app.main:app --host 0.0.0.0 --port 8000
"""
from typing import List, Optional

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware

from . import config
from .face_engine import FaceEngine
from .store import EmbeddingStore

app = FastAPI(title="NCC Face Recognition Service", version="1.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

engine = FaceEngine()
store = EmbeddingStore()


@app.get("/health")
def health():
    return {"status": "ok", "model": config.MODEL_NAME, "enrolled_cadets": len(store.list())}


@app.post("/enroll")
async def enroll(
    cadet_id: str = Form(...),
    name: str = Form(...),
    images: List[UploadFile] = File(...),
):
    embeddings, errors = [], []
    for img_file in images:
        try:
            img = engine.decode_image(await img_file.read())
            embeddings.append(engine.single_face_embedding(img))
        except ValueError as e:
            errors.append({"file": img_file.filename, "error": str(e)})

    if len(embeddings) < config.MIN_ENROLL_IMAGES and cadet_id not in store.list():
        raise HTTPException(
            status_code=422,
            detail={
                "message": f"Need at least {config.MIN_ENROLL_IMAGES} good photos, got {len(embeddings)}",
                "errors": errors,
            },
        )
    total = store.enroll(cadet_id, name, embeddings) if embeddings else 0
    return {"cadet_id": cadet_id, "accepted": len(embeddings), "total_samples": total, "rejected": errors}


@app.get("/cadets")
def list_cadets():
    return store.list()


@app.delete("/cadets/{cadet_id}")
def delete_cadet(cadet_id: str):
    if not store.delete(cadet_id):
        raise HTTPException(status_code=404, detail="Cadet not enrolled")
    return {"deleted": cadet_id}


@app.post("/recognize")
async def recognize(
    image: UploadFile = File(...),
    cadet_ids: Optional[str] = Form(None),  # optional comma-separated list to restrict matches
):
    try:
        img = engine.decode_image(await image.read())
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    faces = engine.detect(img)
    allowed = set(cadet_ids.split(",")) if cadet_ids else None
    good = [(i, f) for i, f in enumerate(faces) if f.embedding is not None]
    matches = store.match_many([f.embedding for _, f in good], allowed)
    match_by_face = {i: m for (i, _), m in zip(good, matches)}

    meta = store.list()
    out, recognized = [], []
    for i, f in enumerate(faces):
        m = match_by_face.get(i)
        entry = {"bbox": f.bbox, "det_score": round(f.det_score, 3)}
        if f.rejected_reason:
            entry["status"] = "rejected"
            entry["reason"] = f.rejected_reason
        elif m is None:
            entry["status"] = "unknown"
        else:
            cid, score = m
            entry.update(status="matched", cadet_id=cid,
                         name=meta.get(cid, {}).get("name"), similarity=round(score, 3))
            recognized.append(cid)
        out.append(entry)

    return {"faces_detected": len(faces), "recognized_cadet_ids": recognized, "faces": out}
