"""Firebase ID-token verification. The user id always comes from the
verified token, never from a request field (README §11)."""

from __future__ import annotations

from dataclasses import dataclass

from fastapi import Depends, Header, HTTPException, status


@dataclass(frozen=True)
class User:
    uid: str
    admin: bool = False


def _verify(token: str) -> dict:
    from firebase_admin import auth  # imported lazily so tests need no credentials

    from .firebase import app

    return auth.verify_id_token(token, app=app(), check_revoked=True)


def current_user(authorization: str | None = Header(default=None)) -> User:
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Missing bearer token")
    try:
        claims = _verify(authorization.removeprefix("Bearer ").strip())
    except Exception:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid or expired token") from None
    return User(uid=claims["uid"], admin=claims.get("admin") is True)


def admin_user(user: User = Depends(current_user)) -> User:
    if not user.admin:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Admin only")
    return user
