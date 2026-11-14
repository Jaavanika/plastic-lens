"""PlasticLens API: LLM second opinion, materials, feedback, admin.

Run locally:  uvicorn app.main:app --reload   (from backend/)
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import settings
from .routers import identify, plastics

app = FastAPI(
    title="PlasticLens API",
    version="1.0.0",
    description="Server-side operations that need a secret or admin rights. "
    "Normal user data goes from the app straight to Firestore.",
)
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins, allow_methods=["GET", "POST", "PUT"], allow_headers=["Authorization", "Content-Type"])
app.include_router(identify.router)
app.include_router(plastics.router)


@app.get("/api/health", tags=["health"])
def health():
    return {"status": "ok", "version": app.version, "model": settings.llm_model}
