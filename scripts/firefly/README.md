# Firefly Sprite Generator

Auto-generates the 6 player-character sprites for Grounds for Defense via the Adobe Firefly Services API.

## Prerequisites

- Python 3.10+
- An Adobe Creative Cloud account
- Adobe Developer Console access

## One-time setup (~10 min)

### 1. Get Adobe API credentials

1. Go to <https://developer.adobe.com/console>
2. Sign in with your Adobe ID (the one with your CC subscription)
3. Click **Create new project**
4. Click **Add API** → search **Firefly Services API** → **Next**
5. Choose **OAuth Server-to-Server** → **Next**
6. (If prompted) Choose a product profile that has Firefly access (your default Creative Cloud profile works)
7. Click **Save configured API**
8. From the **OAuth Server-to-Server** credentials section, copy:
   - **Client ID**
   - **Client Secret** (click "Retrieve client secret" to reveal)

### 2. Configure the script

```bash
cd scripts/firefly

# Install Python deps
python3 -m pip install -r requirements.txt

# Set up env file
cp .env.example .env
# Edit .env and paste your CLIENT_ID and CLIENT_SECRET
```

### 3. (Optional) Set up remove.bg for automatic background stripping

1. Go to <https://www.remove.bg/api>
2. Sign up free → 50 images/month free tier
3. Copy your API key into `.env` as `REMOVE_BG_API_KEY`

## Usage

```bash
# Generate all 6 characters
python3 generate.py

# Generate just one to test
python3 generate.py --char student

# Generate 3 variations of each (then pick favorites)
python3 generate.py --variations 3

# Strip backgrounds via remove.bg
python3 generate.py --remove-bg

# Overwrite existing PNGs
python3 generate.py --force

# Adjust visual intensity (1-10, default 6)
python3 generate.py --visual-intensity 5
```

Output goes to `../../assets/char-*.png` (the game's assets directory).

## Available characters

| `--char` key | Filename | Description |
|---|---|---|
| `student` | `char-student.png` | 20-yr-old Korean-American student, late-night coffee break |
| `commuter` | `char-commuter.png` | 30-yr-old Black professional, iced latte to-go |
| `cyclist` | `char-cyclist.png` | 38-yr-old Mexican-American cyclist, post-ride espresso |
| `parent` | `char-parent.png` | 42-yr-old white mom, "BEST MOM" mug morning ritual |
| `aficionado` | `char-aficionado.png` | 55-yr-old Indian connoisseur, pour-over enthusiast |
| `nonna` | `char-nonna.png` | 75-yr-old Italian-American grandmother, Bialetti moka pot |

## Pricing

- Each generation uses 1 Generative Credit
- Your Creative Cloud subscription includes a monthly Generative Credit allowance
- This script uses 6 credits for a full run (or 18 with `--variations 3`)

## Troubleshooting

**`Adobe auth failed (400)`**
The client_id / client_secret in `.env` are wrong. Re-copy from the Adobe Developer Console.

**`promptHasDeniedWords`**
Firefly's content filter blocked one of the prompts. Edit `prompts.json` to remove the flagged language (most common triggers: any word like `tattoo`, `teen`, body modifications). The current prompts are already filter-safe but Firefly's filter can be unpredictable.

**Generated image has a kitchen background even though we said "transparent"**
Firefly doesn't always honor "transparent background" perfectly. Either:
1. Run with `--remove-bg` (uses remove.bg API)
2. Or open the PNG in Photoshop → **Select → Subject** → invert → delete

**`Insufficient generative credits`**
Your CC plan's monthly credit allowance is exhausted. Wait until next month, or purchase additional credits at <https://helpx.adobe.com/firefly/using/generative-credits.html>

## Editing prompts

To adjust a character's appearance, edit `prompts.json` and re-run with `--force`. The prompts are designed to pass Firefly's content filter (no minors, no tattoos, no risky clothing) — if you change them, keep that in mind.

## Adding new characters

Add a new entry to `prompts.json` with a unique `key` and `filename`, then run:
```bash
python3 generate.py --char {your-new-key}
```
