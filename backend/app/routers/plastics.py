from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from ..auth import User, admin_user, current_user
from ..deps import get_store
from ..schemas.models import Feedback, FeedbackIn, PlasticType
from ..services.store import Store

router = APIRouter(prefix="/api", tags=["materials & feedback"])


@router.get("/plastics", response_model=list[PlasticType])
def list_plastics(store: Store = Depends(get_store)):
    return sorted(store.list_plastics(), key=lambda p: p.resin_code)


@router.get("/plastics/{code}", response_model=PlasticType)
def get_plastic(code: str, store: Store = Depends(get_store)):
    item = store.get_plastic(code.upper())
    if item is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "Unknown material")
    return item


@router.put("/admin/plastics/{code}", response_model=PlasticType)
def put_plastic(code: str, item: PlasticType, _: User = Depends(admin_user), store: Store = Depends(get_store)):
    if item.material != code.upper():
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Path code and body material differ")
    store.put_plastic(item)
    return item


@router.post("/feedback", response_model=Feedback, status_code=status.HTTP_201_CREATED)
def submit_feedback(fb: FeedbackIn, user: User = Depends(current_user), store: Store = Depends(get_store)):
    return store.add_feedback(user.uid, fb)


@router.get("/admin/feedback", response_model=list[Feedback])
def review_feedback(status_filter: str | None = None, limit: int = 100, _: User = Depends(admin_user), store: Store = Depends(get_store)):
    return store.list_feedback(status_filter, min(max(limit, 1), 500))
