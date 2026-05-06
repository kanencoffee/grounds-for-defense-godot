#!/usr/bin/env python3
"""
Generate Grounds for Defense character sprites via Adobe Firefly Services API.

Usage:
    python generate.py                  # generate all characters from prompts.json
    python generate.py --char student   # generate only the student
    python generate.py --variations 3   # generate 3 versions of each (pick favorite)
    python generate.py --force          # overwrite existing PNGs
    python generate.py --remove-bg      # also strip background via remove.bg

Requires environment variables in .env:
    ADOBE_CLIENT_ID
    ADOBE_CLIENT_SECRET
    REMOVE_BG_API_KEY    (optional — enables --remove-bg)

Output: PNG files written to ../../assets/{filename} per prompts.json
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path

import requests
from dotenv import load_dotenv

# ============================================================================
# Constants
# ============================================================================
HERE = Path(__file__).resolve().parent
REPO_ROOT = HERE.parent.parent
ASSETS_DIR = REPO_ROOT / "assets"
PROMPTS_JSON = HERE / "prompts.json"

ADOBE_AUTH_URL = "https://ims-na1.adobelogin.com/ims/token/v3"
ADOBE_FIREFLY_URL = "https://firefly-api.adobe.io/v3/images/generate"
ADOBE_SCOPES = (
    "openid,AdobeID,read_organizations,firefly_api,ff_apis"
)

REMOVE_BG_URL = "https://api.remove.bg/v1.0/removebg"


# ============================================================================
# Auth
# ============================================================================
def get_adobe_token(client_id: str, client_secret: str) -> str:
    """Exchange Adobe client credentials for an access token."""
    resp = requests.post(
        ADOBE_AUTH_URL,
        data={
            "client_id": client_id,
            "client_secret": client_secret,
            "grant_type": "client_credentials",
            "scope": ADOBE_SCOPES,
        },
        timeout=30,
    )
    if not resp.ok:
        print(f"❌ Adobe auth failed ({resp.status_code}): {resp.text}", file=sys.stderr)
        sys.exit(1)
    token = resp.json().get("access_token")
    if not token:
        print(f"❌ No access_token in Adobe response: {resp.json()}", file=sys.stderr)
        sys.exit(1)
    return token


# ============================================================================
# Firefly generation
# ============================================================================
def generate_with_firefly(
    *,
    prompt: str,
    client_id: str,
    access_token: str,
    width: int = 1024,
    height: int = 1024,
    variations: int = 1,
    visual_intensity: int = 6,
    seed: int | None = None,
) -> list[str]:
    """Generate image(s) via Firefly. Returns list of presigned PNG URLs."""
    body = {
        "prompt": prompt,
        "numVariations": variations,
        "size": {"width": width, "height": height},
        "contentClass": "art",
        "visualIntensity": visual_intensity,
        "promptBiasingLocaleCode": "en-US",
    }
    if seed is not None:
        body["seeds"] = [seed]

    resp = requests.post(
        ADOBE_FIREFLY_URL,
        headers={
            "x-api-key": client_id,
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        json=body,
        timeout=180,
    )
    if not resp.ok:
        print(
            f"❌ Firefly API failed ({resp.status_code}): {resp.text}",
            file=sys.stderr,
        )
        sys.exit(1)

    data = resp.json()
    if data.get("promptHasDeniedWords"):
        print(
            "⚠️  Firefly flagged the prompt for denied words. Try the safer-language template.",
            file=sys.stderr,
        )
    if data.get("promptHasBlockedArtists"):
        print(
            "⚠️  Firefly flagged the prompt for blocked artist references.",
            file=sys.stderr,
        )

    outputs = data.get("outputs", [])
    if not outputs:
        print(f"❌ No outputs returned: {data}", file=sys.stderr)
        sys.exit(1)
    return [o["image"]["url"] for o in outputs if o.get("image", {}).get("url")]


# ============================================================================
# Background removal (optional)
# ============================================================================
def remove_background(png_bytes: bytes, api_key: str) -> bytes:
    """Strip the background via remove.bg API. Returns transparent PNG bytes."""
    resp = requests.post(
        REMOVE_BG_URL,
        headers={"X-Api-Key": api_key},
        files={"image_file": ("input.png", png_bytes, "image/png")},
        data={"size": "auto", "format": "png"},
        timeout=60,
    )
    if not resp.ok:
        print(
            f"⚠️  remove.bg failed ({resp.status_code}): {resp.text}. "
            f"Keeping original image.",
            file=sys.stderr,
        )
        return png_bytes
    return resp.content


# ============================================================================
# Download
# ============================================================================
def download_png(url: str) -> bytes:
    resp = requests.get(url, timeout=60)
    resp.raise_for_status()
    return resp.content


# ============================================================================
# Main
# ============================================================================
def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--char",
        help="Only generate this single character key (matches prompts.json)",
    )
    parser.add_argument(
        "--variations",
        type=int,
        default=1,
        help="How many variations to generate per character (default 1)",
    )
    parser.add_argument(
        "--force",
        action="store_true",
        help="Overwrite existing PNGs",
    )
    parser.add_argument(
        "--remove-bg",
        action="store_true",
        help="Strip background via remove.bg API after generation",
    )
    parser.add_argument(
        "--visual-intensity",
        type=int,
        default=6,
        help="Firefly visual intensity 1-10 (default 6)",
    )
    args = parser.parse_args()

    load_dotenv(HERE / ".env")
    client_id = os.environ.get("ADOBE_CLIENT_ID")
    client_secret = os.environ.get("ADOBE_CLIENT_SECRET")
    remove_bg_key = os.environ.get("REMOVE_BG_API_KEY")

    if not client_id or not client_secret:
        print(
            "❌ Missing ADOBE_CLIENT_ID and/or ADOBE_CLIENT_SECRET. "
            "Copy .env.example to .env and fill in.",
            file=sys.stderr,
        )
        sys.exit(1)

    if args.remove_bg and not remove_bg_key:
        print(
            "⚠️  --remove-bg passed but REMOVE_BG_API_KEY not set. "
            "Will skip background removal.",
            file=sys.stderr,
        )

    if not PROMPTS_JSON.exists():
        print(f"❌ Missing {PROMPTS_JSON}", file=sys.stderr)
        sys.exit(1)

    prompts = json.loads(PROMPTS_JSON.read_text())
    if args.char:
        prompts = [p for p in prompts if p["key"] == args.char]
        if not prompts:
            print(
                f"❌ No character with key '{args.char}'. "
                f"Available: {[p['key'] for p in json.loads(PROMPTS_JSON.read_text())]}",
                file=sys.stderr,
            )
            sys.exit(1)

    print(f"🔐 Authenticating with Adobe…")
    token = get_adobe_token(client_id, client_secret)
    print(f"   ✓ token acquired")

    ASSETS_DIR.mkdir(parents=True, exist_ok=True)

    for p in prompts:
        key = p["key"]
        filename = p["filename"]
        prompt = p["prompt"]
        out_path = ASSETS_DIR / filename

        if out_path.exists() and not args.force:
            print(f"⏭  {filename} already exists. Skipping (use --force to overwrite).")
            continue

        print(f"\n🎨 Generating {key}{'+ '+str(args.variations-1)+' alts' if args.variations > 1 else ''}…")
        urls = generate_with_firefly(
            prompt=prompt,
            client_id=client_id,
            access_token=token,
            variations=args.variations,
            visual_intensity=args.visual_intensity,
        )
        print(f"   ✓ Firefly returned {len(urls)} image(s)")

        for i, url in enumerate(urls):
            png_bytes = download_png(url)
            if args.remove_bg and remove_bg_key:
                print(f"   ✂️  Stripping background…")
                png_bytes = remove_background(png_bytes, remove_bg_key)

            if args.variations == 1:
                target = out_path
            else:
                target = out_path.with_name(f"{out_path.stem}-v{i+1}.png")
            target.write_bytes(png_bytes)
            print(f"   💾 Saved {target.relative_to(REPO_ROOT)} ({len(png_bytes):,} bytes)")

        # Be polite with the API
        time.sleep(0.5)

    print(f"\n✅ Done. Files written to {ASSETS_DIR.relative_to(REPO_ROOT)}/")


if __name__ == "__main__":
    main()
