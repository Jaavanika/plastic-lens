from __future__ import annotations

from functools import lru_cache

from .config import settings


@lru_cache(maxsize=1)
def app():
    import firebase_admin

    return firebase_admin.initialize_app(options={"projectId": settings.firebase_project})


def firestore_client():
    from firebase_admin import firestore

    return firestore.client(app())
