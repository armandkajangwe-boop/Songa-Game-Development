#!/usr/bin/env python3
"""Exercise the downloadable game offline in real desktop and mobile Chromium.

Run from any directory: python tests/browser-ui.py
Requires Playwright for Python and /usr/bin/chromium; no server or browser
download is needed. If managed browser policy blocks file://, pass
--managed-browser to fulfill the same HTML bytes in memory at an allowed test
origin, with offline mode still enabled; this does not validate file:// access.
Fixtures place hazards in the public simulation; all menu,
jump, slide, pause and restart actions use real browser input dispatch.
"""

from pathlib import Path
import math
import sys

from playwright.sync_api import sync_playwright


ROOT = Path(__file__).resolve().parents[1]
ARTIFACTS = ROOT / "artifacts"
MANAGED_BROWSER = "--managed-browser" in sys.argv
TEST_ORIGIN = "http://localhost:31460"
DOWNLOAD = TEST_ORIGIN + "/Songa-Play.html" if MANAGED_BROWSER else (ARTIFACTS / "Songa-Play.html").as_uri()
INDEX = TEST_ORIGIN + "/index.html" if MANAGED_BROWSER else (ROOT / "index.html").as_uri()
DOCUMENTS = {TEST_ORIGIN + "/Songa-Play.html": ARTIFACTS / "Songa-Play.html",
             TEST_ORIGIN + "/index.html": ROOT / "index.html"} if MANAGED_BROWSER else {}
MODEL = "window.SongaPreview.model"
checks = 0
errors = []
network_requests = []


def check(condition, message):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(message)


def value(page, expression):
    return page.evaluate(f"() => {{ const m = {MODEL}; return ({expression}); }}")


def until(page, expression):
    page.wait_for_function(
        f"() => {{ const m = {MODEL}; return ({expression}); }}", timeout=5000
    )


def ready(page, url=DOWNLOAD):
    page.goto(url, wait_until="load")
    page.wait_for_function("window.SongaPreview && window.SongaPreview.ready", timeout=10000)


def attach(page):
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.on("console", lambda msg: errors.append(msg.text) if msg.type == "error" else None)


def context(browser, **options):
    result = browser.new_context(offline=True, service_workers="block", **options)

    def request(route):
        if route.request.url in DOCUMENTS:
            route.fulfill(status=200, content_type="text/html", body=DOCUMENTS[route.request.url].read_text())
        elif route.request.url.startswith(("http://", "https://")):
            network_requests.append(route.request.url)
            route.abort()
        else:
            route.continue_()

    result.route("**/*", request)
    result.on("page", attach)
    return result


def blank_course(page):
    page.evaluate(f"() => {{const m={MODEL};m.obstacles=[];m.pickups=[];m._spawnRemaining=1e9;}}")


def canvas_point(page, x, y):
    box = page.locator("#world").bounding_box()
    return box["x"] + x * box["width"] / 540, box["y"] + y * box["height"] / 960


def center(page, selector):
    box = page.locator(selector).bounding_box()
    return box["x"] + box["width"] / 2, box["y"] + box["height"] / 2


def desktop(browser):
    ctx = context(browser, viewport={"width": 540, "height": 960}, device_scale_factor=1)
    page = ctx.new_page()
    ready(page)
    check(page.locator("#home").is_visible(), "Downloaded self-contained HTML opens on the title")
    check(value(page, "m.phase === 'title'"), "Initial simulation phase is title")
    check(page.locator("#loading").is_hidden(), "Embedded images and fonts finish loading offline")
    page.screenshot(path=str(ARTIFACTS / "browser-title.png"))
    page.locator("#sound").click()
    check(page.locator("#sound").inner_text() == "SOUND OFF", "Sound button mutes")
    page.locator("#start").click()
    until(page, "m.phase === 'running' && m.distance > 1")
    blank_course(page)
    check(page.locator("#home").is_hidden(), "Start click hides title")
    check(page.locator("#run-hud").is_visible(), "Start click displays HUD")
    check(page.locator("#jump").is_enabled(), "Start enables jump control")
    before = value(page, "m.distance")
    page.wait_for_timeout(150)
    check(value(page, "m.distance") > before, "Animation frames advance distance")

    # A canvas tap is decided on release, unlike an explicit jump button.
    x, y = canvas_point(page, 370, 420)
    page.mouse.move(x, y)
    page.mouse.down()
    check(value(page, "m.velocityY === 0"), "Canvas pointer down does not prematurely jump")
    page.mouse.up()
    until(page, "m.velocityY < 0 && m.playerY < m.groundY")
    check(value(page, "m.playerY < m.groundY"), "Canvas tap produces a visible jump")
    until(page, "m.isGrounded()")
    x, y = center(page, "#jump")
    page.mouse.move(x, y)
    page.mouse.down()
    until(page, "m.velocityY < 0")
    check(value(page, "!m.isGrounded()"), "Jump button acts on press before release")
    page.mouse.up()
    until(page, "m.isGrounded()")

    x, y = center(page, "#slide")
    page.mouse.move(x, y)
    page.mouse.down()
    until(page, "m.ducking")
    page.wait_for_timeout(950)
    check(value(page, "m.ducking && m.isGrounded()"), "Held slide persists beyond the swipe timer")
    page.mouse.up()
    until(page, "!m.ducking")
    check(value(page, "m.velocityY === 0"), "Slide release does not turn into a jump")

    # Pause must clear both a held keyboard slide and the rendered world clock.
    page.keyboard.down("ArrowDown")
    until(page, "m.ducking")
    page.locator("#pause").click()
    until(page, "m.phase === 'paused'")
    frozen = value(page, "[m.elapsed,m.distance,m.playerY]")
    page.wait_for_timeout(250)
    check(value(page, "[m.elapsed,m.distance,m.playerY]") == frozen, "Pause freezes simulation")
    check(not value(page, "m.ducking"), "Pause clears held slide")
    check(page.locator("#jump").is_disabled(), "Paused controls are disabled")
    page.keyboard.up("ArrowDown")
    page.locator("#resume").click()
    until(page, "m.phase === 'running'")
    check(not value(page, "m.ducking"), "Resume leaves slide released")
    page.locator("#pause").focus()
    page.keyboard.down("Space")
    until(page, "m.velocityY < 0")
    check(value(page, "m.phase === 'running'"), "Space jumps while pause button has keyboard focus")
    page.keyboard.up("Space")
    check(page.locator("#paused").is_hidden(), "Space release does not activate focused pause button")
    until(page, "m.isGrounded()")

    # A staged real hazard is consumed by the ordinary RAF collision path.
    page.evaluate(f"{MODEL}.bananas = 4")
    page.screenshot(path=str(ARTIFACTS / "browser-running.png"))
    for hit in range(3):
        page.evaluate(f"""() => {{
            const m={MODEL}; m.invulnerability=0;
            m.obstacles=[{{x:m.playerX,y:m.groundY-48,width:42,height:48,kind:'rock'}}];
        }}""")
        until(page, f"m.lives === {2 - hit}")
        check(value(page, "m.lives") == 2 - hit, f"Collision {hit + 1} removes one heart")
    until(page, "m.phase === 'game_over'")
    check(page.locator("#results").is_visible(), "Third collision displays results")
    check(page.locator("#result-bananas").inner_text() == "4", "Results show collected bananas")
    check(page.locator("#jump").is_disabled(), "Results disable jump control")
    best = value(page, "m.bestDistance")
    check(best > 0, "Completed run has a personal best")
    page.locator("#restart").click()
    until(page, "m.phase === 'running'")
    blank_course(page)
    check(value(page, "m.lives === 3 && m.bananas === 0 && m.distance < 3"), "Restart clears the previous run")
    check(value(page, "m.bestDistance") == best, "Restart preserves best distance")
    page.locator("#pause").click()
    page.locator("#pause-home").click()
    check(page.locator("#home").is_visible(), "Back to camp restores title")
    ready(page)
    check(value(page, "m.bestDistance") == best, "Reload restores saved best distance")
    check(page.locator("#sound").inner_text() == "SOUND OFF", "Reload restores muted preference")
    check(str(math.floor(best)) in page.locator("#personal-best").inner_text(), "Restored best appears in title")
    # The repository's root file is independently usable offline as well.
    ready(page, INDEX)
    check(page.locator("#start").is_visible(), "Root index.html also loads offline")
    ctx.close()


def touch(client, kind, x=None, y=None):
    points = [] if kind == "touchEnd" else [{"x": x, "y": y, "id": 1}]
    client.send("Input.dispatchTouchEvent", {"type": kind, "touchPoints": points})


def mobile(browser):
    ctx = context(browser, viewport={"width": 390, "height": 844}, device_scale_factor=1,
                  is_mobile=True, has_touch=True)
    page = ctx.new_page()
    ready(page)
    page.locator("#sound").tap()
    page.locator("#start").tap()
    until(page, "m.phase === 'running'")
    blank_course(page)
    client = ctx.new_cdp_session(page)
    x, y = canvas_point(page, 370, 420)
    touch(client, "touchStart", x, y)
    check(value(page, "m.velocityY === 0"), "Real touchscreen press waits for gesture")
    touch(client, "touchEnd")
    until(page, "m.velocityY < 0 && m.playerY < m.groundY")
    check(value(page, "m.playerY < m.groundY"), "Real touchscreen tap jumps")
    until(page, "m.isGrounded()")
    x, y = canvas_point(page, 370, 350)
    _, bottom = canvas_point(page, 370, 440)
    touch(client, "touchStart", x, y)
    touch(client, "touchMove", x, bottom)
    until(page, "m.ducking")
    check(value(page, "m.velocityY === 0 && m.isGrounded()"), "Down swipe slides without jumping")
    touch(client, "touchEnd")
    check(value(page, "m.velocityY === 0"), "Swipe release does not also jump")
    until(page, "!m.ducking")
    check(value(page, "m.isGrounded()"), "Timed touch slide expires on the ground")
    x, y = center(page, "#slide")
    touch(client, "touchStart", x, y)
    until(page, "m.ducking")
    check(value(page, "m.ducking"), "Touchscreen slide button holds the crouch")
    touch(client, "touchEnd")
    until(page, "!m.ducking")
    check(value(page, "!m.ducking"), "Lifting from touchscreen slide clears crouch")
    page.screenshot(path=str(ARTIFACTS / "browser-mobile.png"))

    for width, height in [(390, 844), (320, 568), (430, 932)]:
        page.set_viewport_size({"width": width, "height": height})
        page.wait_for_timeout(80)
        for selector in ["#slide", "#jump", "#pause"]:
            box = page.locator(selector).bounding_box()
            check(box is not None and box["x"] >= -0.5 and box["y"] >= -0.5 and
                  box["x"] + box["width"] <= width + 0.5 and
                  box["y"] + box["height"] <= height + 0.5,
                  f"{selector} remains inside {width}×{height} portrait viewport")
        check(page.evaluate("document.documentElement.scrollWidth <= innerWidth"),
              f"Portrait {width}×{height} has no horizontal overflow")
    client.detach()
    ctx.close()


def main():
    ARTIFACTS.mkdir(exist_ok=True)
    with sync_playwright() as playwright:
        browser = playwright.chromium.launch(executable_path="/usr/bin/chromium", headless=True,
                                             args=["--no-sandbox", "--disable-dev-shm-usage"])
        try:
            desktop(browser)
            mobile(browser)
            check(not errors, f"No browser errors: {errors}")
            check(not network_requests, f"No HTTP/HTTPS requests while fully offline: {network_requests}")
        finally:
            browser.close()
    mode = "in-memory document route (managed browser blocks file://)" if MANAGED_BROWSER else "file://"
    print(f"Songa browser UI: {checks} checks, 0 failures; offline desktop and touch Chromium; {mode}")


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"Songa browser UI: FAILED after {checks} checks: {error}", file=sys.stderr)
        sys.exit(1)
