# Songa — Rise of the Silverback

A portrait, one-handed **2D endless runner** set in an illustrated Volcanoes National Park, Kinigi, Musanze, Rwanda. Help young Songa leap over volcanic rocks and fallen logs, slide under bamboo boughs, and collect bananas while a larger silverback follows behind.

This includes a playable browser preview and a **Godot 4.6.3 / GDScript** project for continued mobile development, with Astra contributing the gameplay simulation and review. Signed phone builds and store releases are not included yet.

In-engine screenshots: [home screen](docs/screenshots/title.png) · [staged gameplay](docs/screenshots/running.png).

## Play now — no editor required

Download **`index.html`** from this repository (use **Download raw file**, rather than saving GitHub's file viewer). Open the downloaded file in Chrome, Edge, Firefox, or Safari, then select **LET'S RUN**.

The file contains its artwork, fonts, sounds, and gameplay. It works offline without a server, installation, or account. The workspace also has an identical copy at `artifacts/Songa-Play.html`.

Use a desktop browser for the simplest local-file experience. A hosted copy supports mobile browsers; some phone file managers show downloaded HTML in a preview that does not execute JavaScript. That file-manager preview cannot play the game.

For a web link from GitHub, an owner can enable **Settings → Pages → Deploy from a branch**, select the branch containing `index.html`, and select **/ (root)**. GitHub then supplies the published site URL. This repository does not itself establish that Pages is enabled; do not treat an inferred Pages address as an already-live game.

## Develop the Godot version

1. Install [Godot 4.6.3](https://godotengine.org/download/archive/4.6.3-stable/) (standard edition; .NET is not needed).
2. Import `project.godot` in the Godot Project Manager.
3. Press **F5** to run the project.

From a terminal in this directory:

```sh
godot --editor --path .
# Or play directly:
godot --path .
```

| Action | Phone | Desktop |
| --- | --- | --- |
| Jump | Tap the play area or JUMP button | Space / Up / W, or click the play area |
| Slide | Swipe down for a short slide, or hold SLIDE | Hold Down / S / Shift, or drag downward |
| Pause | Tap the pause button | P / Escape |
| Resume / restart | On-screen buttons | On-screen buttons; Space restarts from results |

Three collisions end a run. A short grace period prevents repeated damage from one obstacle. The chase closes as hearts are lost. Speed rises gradually, and each generated encounter has room to react. Best distance and sound preference are saved **locally on the device**. Leaving the app pauses play.

## Included

- Portrait 540 × 960 logical canvas, scaled with the aspect ratio preserved.
- Layered misty Virunga peaks, bamboo, volcanic stones, and forest trail.
- Animated temporary gorillas with run, jump, and crouch poses.
- Seeded, frame-rate-independent obstacle generation, pickups, scoring, increasing speed, and a pursuing gorilla.
- Home, gameplay, pause, and results screens, touch controls, and original synthesized feedback sounds.
- Separate simulation and scene integration tests.
- English interface and no network services, advertising, accounts, analytics, or external packages.

## Verify

```sh
sh tools/check.sh
# Browser simulation (Node.js, no packages):
node tests/browser-model.mjs
# Rebuild the self-contained browser game (Python 3, no packages):
python tools/build_browser.py
# Browser UI checks (Playwright and Chromium are needed for tests only):
python tests/browser-ui.py
# Managed cloud Chromium blocks file://; validate the same bytes offline:
python tests/browser-ui.py --managed-browser
```

The shell script imports Godot assets, runs deterministic gameplay tests, then exercises the real scene, controls, screens, and saved preferences. Browser tests separately exercise the portable simulation and the actual offline HTML file. Tests use isolated user data. Physical device testing is still needed to tune touch feel.

The web preview uses a JavaScript port of the same deterministic mechanics and exported prototype artwork. It does not require downloading the Godot WebAssembly runtime. Browser source lives in `web/`; `tools/build_browser.py` embeds it into `index.html`. The Godot project remains the native mobile-development foundation.

## Cloud workspace

The current environment supplies Godot 4.6.3. Use the existing checkout; each cloud task is already isolated and does not need a Git worktree.

```sh
export XDG_DATA_HOME=/workspace/.songa-runtime/data
export XDG_CONFIG_HOME=/workspace/.songa-runtime/config
export XDG_CACHE_HOME=/workspace/.songa-runtime/cache
mkdir -p "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
godot --headless --path . --editor --import
sh tools/check.sh
```

Headless mode can test gameplay but does not display the game. For normal play, open the project in Godot on a machine with a display. Nothing needs to keep running in the background.

## Art and branding

The illustrated gorillas, scenery, app icon, sounds, and typeset title are **temporary original prototype assets**. They are not a recreation of the final Songa character design. The logo supplied in chat remains a visual reference; its original image file is not bundled in this checkout.

An approved transparent PNG placed at `assets/branding/songa_logo.png` automatically replaces the typeset home-screen title. Character animation can be swapped independently of gameplay through `scripts/gorilla_art.gd` and `_update_characters()` in `scripts/game.gd`.

Open Sans is bundled under the Apache License 2.0; see `assets/fonts/LICENSE.txt`. No third-party art or audio is bundled.

See [design decisions](docs/GAME_DESIGN.md) and [mobile release steps](docs/MOBILE.md) for the agreed direction and what remains.
