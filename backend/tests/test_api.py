"""Backend tests (PLAN Section 7). The LLM is always mocked: no API key or
network needed, and no money spent."""

from __future__ import annotations

import io
import json
from types import SimpleNamespace

import pytest
from fastapi import Header, HTTPException
from fastapi.testclient import TestClient

from app.auth import User, current_user
from app.deps import get_limiter, get_llm, get_store
from app.main import app
from app.schemas.models import PlasticType
from app.services.rate_limit import RateLimiter
from app.services.store import MemoryStore
from app.services.vision_llm import LLMUnavailable, VisionLLM, parse_result

JPEG = b"\xff\xd8\xff\xe0" + b"\x00" * 100
PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 100

PET = PlasticType(
    material="PET", full_name="Polyethylene Terephthalate", resin_code=1, description="d",
    properties=["Light"], common_items=["Bottles"], recycling_guidance=["Rinse"],
    recyclability_rating=4, recyclability_note="n", fact="f", eco_tip="t",
)


def fake_user(authorization: str | None = Header(default=None)) -> User:
    # "Bearer <uid>" or "Bearer admin:<uid>"
    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(401, "Missing bearer token")
    token = authorization.removeprefix("Bearer ")
    return User(uid=token.removeprefix("admin:"), admin=token.startswith("admin:"))


class FakeLLM:
    def __init__(self, result=None, error: Exception | None = None):
        self.result, self.error, self.calls = result, error, 0

    async def identify(self, image: bytes, media_type: str):
        self.calls += 1
        if self.error:
            raise self.error
        return self.result


@pytest.fixture
def ctx():
    store = MemoryStore([PET])
    llm = FakeLLM(parse_result(json.dumps({
        "object_name": "Water bottle", "contains_plastic": True, "resin_code_visible": 1,
        "likely_polymer": "PET", "notes": "Clear ribbed bottle"})))
    limiter = RateLimiter(limit=3)
    app.dependency_overrides.update({current_user: fake_user, get_store: lambda: store, get_llm: lambda: llm, get_limiter: lambda: limiter})
    yield SimpleNamespace(client=TestClient(app), store=store, llm=llm)
    app.dependency_overrides.clear()


def upload(client, data=JPEG, user="alice", name="photo.jpg"):
    headers = {"Authorization": f"Bearer {user}"} if user else {}
    return client.post("/api/identify/enrich", files={"image": (name, io.BytesIO(data), "image/jpeg")}, headers=headers)


def test_health(ctx):
    r = ctx.client.get("/api/health")
    assert r.status_code == 200 and r.json()["status"] == "ok"


def test_enrich_returns_validated_json(ctx):
    r = upload(ctx.client)
    assert r.status_code == 200
    assert r.json() == {"object_name": "Water bottle", "contains_plastic": True, "resin_code_visible": 1,
                        "likely_polymer": "PET", "notes": "Clear ribbed bottle"}


def test_enrich_requires_auth(ctx):
    assert upload(ctx.client, user=None).status_code == 401


def test_enrich_rejects_non_images_and_large_files(ctx):
    assert upload(ctx.client, data=b"%PDF-1.7 not an image").status_code == 415
    assert upload(ctx.client, data=PNG).status_code == 200
    big = JPEG + b"\x00" * (5 * 1024 * 1024)
    assert upload(ctx.client, data=big).status_code == 413
    assert ctx.llm.calls == 1  # rejected uploads never reach the LLM


def test_enrich_rate_limited_per_user(ctx):
    assert [upload(ctx.client).status_code for _ in range(4)] == [200, 200, 200, 429]
    assert upload(ctx.client, user="bob").status_code == 200


def test_llm_failure_is_a_clean_503(ctx):
    ctx.llm.error = LLMUnavailable("invalid model output")
    r = upload(ctx.client)
    assert r.status_code == 503


@pytest.mark.parametrize("bad", [
    "not json",
    "[]",
    json.dumps({"object_name": "", "contains_plastic": True, "resin_code_visible": None, "likely_polymer": None, "notes": None}),
    json.dumps({"object_name": "Cup", "contains_plastic": "yes", "resin_code_visible": None, "likely_polymer": None, "notes": None}),
    json.dumps({"object_name": "Cup", "contains_plastic": True, "resin_code_visible": 12, "likely_polymer": None, "notes": None}),
    json.dumps({"object_name": "Cup", "contains_plastic": True, "resin_code_visible": None, "likely_polymer": "NYLON", "notes": None}),
    json.dumps({"object_name": "Cup", "contains_plastic": True, "resin_code_visible": None, "likely_polymer": None, "notes": None, "extra": 1}),
])
def test_invalid_llm_output_is_rejected(bad):
    with pytest.raises(LLMUnavailable):
        parse_result(bad)


class _FakeMessages:
    def __init__(self, response):
        self.response, self.kwargs = response, None

    async def create(self, **kwargs):
        self.kwargs = kwargs
        return self.response


def _client_returning(text: str | None, stop_reason="end_turn"):
    content = [] if text is None else [SimpleNamespace(type="text", text=text)]
    messages = _FakeMessages(SimpleNamespace(stop_reason=stop_reason, content=content))
    return SimpleNamespace(beta=SimpleNamespace(messages=messages)), messages


async def test_vision_llm_request_shape_and_parsing():
    client, messages = _client_returning(json.dumps({"object_name": "Milk jug", "contains_plastic": True,
                                                     "resin_code_visible": None, "likely_polymer": "HDPE", "notes": None}))
    result = await VisionLLM(client).identify(JPEG, "image/jpeg")
    assert result.object_name == "Milk jug" and result.likely_polymer == "HDPE"
    kw = messages.kwargs
    assert kw["model"] == "claude-opus-5-5"
    assert kw["output_config"]["format"]["type"] == "json_schema"
    assert kw["fallbacks"] == "default"
    image_block = kw["messages"][0]["content"][0]
    assert image_block["type"] == "image" and image_block["source"]["media_type"] == "image/jpeg"


@pytest.mark.parametrize("text,stop", [(None, "end_turn"), ("{}", "refusal"), ('{"object_na', "max_tokens"), ("garbage", "end_turn")])
async def test_vision_llm_failures_raise_unavailable(text, stop):
    client, _ = _client_returning(text, stop)
    with pytest.raises(LLMUnavailable):
        await VisionLLM(client).identify(JPEG, "image/jpeg")


def test_public_materials(ctx):
    assert [p["material"] for p in ctx.client.get("/api/plastics").json()] == ["PET"]
    assert ctx.client.get("/api/plastics/pet").json()["resin_code"] == 1
    assert ctx.client.get("/api/plastics/NYLON").status_code == 404


def test_admin_endpoints_need_admin(ctx):
    body = PET.model_dump() | {"fact": "Updated fact"}
    assert ctx.client.put("/api/admin/plastics/PET", json=body, headers={"Authorization": "Bearer alice"}).status_code == 403
    r = ctx.client.put("/api/admin/plastics/PET", json=body, headers={"Authorization": "Bearer admin:root"})
    assert r.status_code == 200 and ctx.store.get_plastic("PET").fact == "Updated fact"
    assert ctx.client.put("/api/admin/plastics/PP", json=body, headers={"Authorization": "Bearer admin:root"}).status_code == 400


def test_feedback_uses_token_identity(ctx):
    body = {"scan_id": "s1", "predicted": "PET", "corrected": "PP", "confidence": 0.6, "model_version": "v1"}
    r = ctx.client.post("/api/feedback", json=body, headers={"Authorization": "Bearer alice"})
    assert r.status_code == 201 and r.json()["user_id"] == "alice"
    # A user_id in the body is not accepted (identity comes from the token).
    assert ctx.client.post("/api/feedback", json=body | {"user_id": "bob"}, headers={"Authorization": "Bearer alice"}).status_code == 422
    assert ctx.client.get("/api/admin/feedback", headers={"Authorization": "Bearer alice"}).status_code == 403
    assert len(ctx.client.get("/api/admin/feedback", headers={"Authorization": "Bearer admin:root"}).json()) == 1
