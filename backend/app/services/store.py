"""Data access for materials and feedback (Firestore in production)."""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Protocol

from ..schemas.models import Feedback, FeedbackIn, PlasticType


class Store(Protocol):
    def list_plastics(self) -> list[PlasticType]: ...
    def get_plastic(self, code: str) -> PlasticType | None: ...
    def put_plastic(self, item: PlasticType) -> None: ...
    def add_feedback(self, uid: str, fb: FeedbackIn) -> Feedback: ...
    def list_feedback(self, status: str | None, limit: int) -> list[Feedback]: ...


class FirestoreStore:
    def __init__(self, db=None):
        from ..firebase import firestore_client

        self.db = db or firestore_client()

    def list_plastics(self) -> list[PlasticType]:
        return [PlasticType.model_validate(d.to_dict()) for d in self.db.collection("plastic_types").stream()]

    def get_plastic(self, code: str) -> PlasticType | None:
        snap = self.db.collection("plastic_types").document(code).get()
        return PlasticType.model_validate(snap.to_dict()) if snap.exists else None

    def put_plastic(self, item: PlasticType) -> None:
        self.db.collection("plastic_types").document(item.material).set(item.model_dump())

    def add_feedback(self, uid: str, fb: FeedbackIn) -> Feedback:
        from firebase_admin import firestore

        ref = self.db.collection("feedback").document()
        ref.set({**fb.model_dump(), "user_id": uid, "status": "new", "created_at": firestore.SERVER_TIMESTAMP})
        return Feedback(id=ref.id, user_id=uid, **fb.model_dump())

    def list_feedback(self, status: str | None, limit: int) -> list[Feedback]:
        q = self.db.collection("feedback")
        if status:
            q = q.where("status", "==", status)
        out = []
        for d in q.limit(limit).stream():
            data = d.to_dict()
            created = data.get("created_at")
            data["created_at"] = created.isoformat() if hasattr(created, "isoformat") else created
            out.append(Feedback(id=d.id, **data))
        return out


class MemoryStore:
    """In-memory store for tests and local runs without Firebase."""

    def __init__(self, plastics: list[PlasticType] | None = None):
        self.plastics = {p.material: p for p in plastics or []}
        self.feedback: list[Feedback] = []

    def list_plastics(self) -> list[PlasticType]:
        return list(self.plastics.values())

    def get_plastic(self, code: str) -> PlasticType | None:
        return self.plastics.get(code)

    def put_plastic(self, item: PlasticType) -> None:
        self.plastics[item.material] = item

    def add_feedback(self, uid: str, fb: FeedbackIn) -> Feedback:
        item = Feedback(id=uuid.uuid4().hex, user_id=uid, created_at=datetime.now(timezone.utc).isoformat(), **fb.model_dump())
        self.feedback.append(item)
        return item

    def list_feedback(self, status: str | None, limit: int) -> list[Feedback]:
        return [f for f in self.feedback if status is None or f.status == status][:limit]
