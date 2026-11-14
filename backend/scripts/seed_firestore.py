"""Upload the bundled material database and achievement definitions to
Firestore (`plastic_types`, `achievements`), and optionally make a user admin.

Needs a service-account key: Firebase Console -> Project settings ->
Service accounts -> Generate new private key. Save it OUTSIDE the repo or as
backend/serviceAccountKey.json (git-ignored).

    python backend/scripts/seed_firestore.py --key path/to/key.json
    python backend/scripts/seed_firestore.py --key key.json --make-admin you@example.com
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import firebase_admin
from firebase_admin import auth, credentials, firestore

REPO = Path(__file__).resolve().parents[2]
DATA = REPO / "android_app" / "assets" / "data"


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--key", required=True, help="service-account JSON")
    p.add_argument("--make-admin", metavar="EMAIL", help="grant the admin custom claim to this user")
    args = p.parse_args()

    app = firebase_admin.initialize_app(credentials.Certificate(args.key))
    db = firestore.client(app)

    materials = json.loads((DATA / "plastic_types.json").read_text(encoding="utf-8"))["materials"]
    for m in materials:
        db.collection("plastic_types").document(m["material"]).set(m)
    print(f"plastic_types: {len(materials)} documents")

    ach = json.loads((DATA / "achievements.json").read_text(encoding="utf-8"))
    for a in ach["achievements"]:
        db.collection("achievements").document(a["id"]).set(a)
    db.collection("achievements").document("_points").set(ach["points"])
    print(f"achievements: {len(ach['achievements'])} documents")

    if args.make_admin:
        user = auth.get_user_by_email(args.make_admin, app=app)
        auth.set_custom_user_claims(user.uid, {"admin": True}, app=app)
        print(f"{args.make_admin} is now an admin (sign out and in again to refresh the token)")


if __name__ == "__main__":
    main()
