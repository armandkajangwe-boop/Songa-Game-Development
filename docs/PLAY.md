# How to play Songa

## Download and open

1. Download **Songa-Play.html** from the chat, or use **Download raw file** on `index.html` in GitHub.
2. Open that saved HTML file in a desktop browser such as Chrome, Edge, Firefox, or Safari.
3. Select **LET'S RUN**.

Everything is embedded in the file; no Godot installation or local server is needed. Double-clicking a source ZIP does not launch a game, and GitHub's file viewer displays code rather than playing HTML.

Tap/click the play area or press Space to jump. Swipe/drag down to slide, or hold the SLIDE button / Down key. Use the pause button or P/Escape to pause. The game also pauses when its browser tab loses focus. Your best distance and sound choice are saved locally when the browser allows storage.

## Playing on a phone

The game has responsive portrait controls and supports mobile browser touch input. Opening a downloaded HTML file from a phone's file manager may display a non-interactive document preview. For a reliable phone experience, open a hosted web link or, later, install a packaged Android/iOS build.

## Host through GitHub Pages

A repository owner can deploy the generated `index.html` without a build system:

1. Make sure the branch to be deployed contains `index.html` and `.nojekyll` at its root.
2. Open the repository's **Settings → Pages**.
3. Set the source to **Deploy from a branch**, choose that branch, and choose **/ (root)**.
4. Save, wait for GitHub's deployment to finish, and open the website URL GitHub displays.

Pages must be supported by the repository's visibility and plan. The game and any included art become publicly reachable when published to a public site. A prepared HTML file or a pushed branch is not proof of a completed deployment.

## Regenerate the file

```sh
python tools/build_browser.py
node tests/browser-model.mjs
python tests/browser-ui.py
```

The first command creates `index.html` plus the identical `artifacts/Songa-Play.html`. Browser tests require Playwright with Chromium only during development, not for playing.
