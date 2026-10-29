// Run with: node --test tests/browser-model.mjs
import test from "node:test";
import assert from "node:assert/strict";
import "../web/runner-model.js";

const Model = globalThis.SongaRunnerModel;

function advance(model, seconds, delta = 1 / 60) {
  for (let frame = 0; frame < Math.round(seconds / delta); frame++) model.tick(delta);
}

function blank(seed = 42) {
  const model = new Model(seed);
  model.begin();
  model._spawnRemaining = 1e6;
  return model;
}

function hazard(x, kind = "rock") {
  if (kind === "branch") return { x, y: 585, width: 74, height: 105, kind };
  if (kind === "log") return { x, y: 702, width: 64, height: 38, kind };
  return { x, y: 692, width: 42, height: 48, kind };
}

function snapshot(model) {
  const fields = ["phase", "distance", "elapsed", "speed", "playerY", "velocityY",
    "ducking", "lives", "bananas", "hitFlash", "invulnerability", "chasePressure",
    "obstacles", "pickups", "_patternCount", "_randomState"];
  return JSON.parse(JSON.stringify(Object.fromEntries(fields.map(key => [key, model[key]]))));
}

test("title, pause and game-over freeze simulation; resume continues the airborne pose", () => {
  const model = new Model();
  assert.equal(model.phase, "title");
  assert.equal(model.jump(), false);
  advance(model, 1);
  assert.equal(model.distance, 0);
  model.begin();
  advance(model, 1);
  model.jump();
  model.tick(1 / 60);
  model.togglePause();
  const paused = snapshot(model);
  advance(model, 3);
  assert.equal(model.jump(), false);
  assert.deepEqual(snapshot(model), paused);
  model.togglePause();
  model.tick(1 / 60);
  assert.ok(model.elapsed > paused.elapsed);
  assert.ok(model.playerY < paused.playerY);
  model.phase = "game_over";
  const ended = snapshot(model);
  advance(model, 1);
  model.togglePause();
  assert.deepEqual(snapshot(model), ended);
});

test("invalid deltas are ignored and a suspended frame cannot advance more than 250ms", () => {
  const model = blank();
  const initial = snapshot(model);
  for (const delta of [-1, 0, NaN, Infinity, undefined, "1"]) model.tick(delta);
  assert.deepEqual(snapshot(model), initial);
  model.tick(60);
  assert.ok(Math.abs(model.elapsed - 0.25) < 1e-10);
});

test("collisions consume three hearts with grace and freeze the result", () => {
  const model = blank();
  model.obstacles.push(hazard(160));
  model.tick(1 / 60);
  assert.equal(model.lives, 2);
  assert.ok(model.hitFlash > 0);
  model.obstacles.push(hazard(160, "log"));
  model.tick(1 / 60);
  assert.equal(model.lives, 2, "second obstacle is protected by grace");
  advance(model, 1.5);
  model.obstacles.push(hazard(160));
  model.tick(1 / 60);
  assert.equal(model.lives, 1);
  advance(model, 1.5);
  model.obstacles.push(hazard(160));
  model.tick(1 / 60);
  assert.equal(model.lives, 0);
  assert.equal(model.phase, "game_over");
  const final = snapshot(model);
  advance(model, 3);
  assert.deepEqual(snapshot(model), final);
});

test("a lingering obstacle hits once, and thin hazards cannot tunnel across slow frames", () => {
  const lingering = blank();
  lingering.obstacles.push({ ...hazard(140), width: 1000 });
  advance(lingering, 3);
  assert.equal(lingering.lives, 2);
  const hitch = blank();
  hitch.elapsed = 100;
  hitch.obstacles.push({ ...hazard(190), width: 1 });
  hitch.tick(0.25);
  assert.equal(hitch.lives, 2);
});

test("jumps clear rocks and logs, cannot double jump, and land exactly", () => {
  for (const kind of ["rock", "log"]) {
    const model = blank();
    model.obstacles.push(hazard(220, kind));
    assert.equal(model.jump(), true);
    model.tick(1 / 60);
    const velocity = model.velocityY;
    assert.equal(model.jump(), false);
    assert.equal(model.velocityY, velocity);
    advance(model, 1);
    assert.equal(model.lives, 3, `${kind} is safely jumpable`);
    assert.equal(model.playerY, 740);
    assert.equal(model.velocityY, 0);
    assert.equal(model.isGrounded(), true);
  }
});

test("standing hits a branch, held duck clears it, and pause-time release cannot stick", () => {
  const standing = blank();
  standing.obstacles.push(hazard(160, "branch"));
  standing.tick(1 / 60);
  assert.equal(standing.lives, 2);
  const sliding = blank();
  sliding.obstacles.push(hazard(220, "branch"));
  sliding.setDucking(true);
  advance(sliding, 1);
  assert.equal(sliding.lives, 3);
  assert.equal(sliding.ducking, true);
  sliding.togglePause();
  sliding.setDucking(false);
  sliding.togglePause();
  sliding.tick(1 / 60);
  assert.equal(sliding.ducking, false);
  sliding.obstacles.push(hazard(160));
  sliding.setDucking(true);
  sliding.tick(1 / 60);
  assert.equal(sliding.lives, 2, "ducking cannot evade ground hazards");
});

test("bananas require proximity and score exactly once", () => {
  const model = blank();
  model.pickups.push({ x: 160, y: 700 });
  model.tick(1 / 60);
  assert.equal(model.bananas, 1);
  assert.equal(model.pickups.length, 0);
  advance(model, 0.5);
  assert.equal(model.bananas, 1);
  model.pickups.push({ x: 160, y: 500 });
  model.tick(1 / 60);
  assert.equal(model.bananas, 1);
});

test("restart resets the complete run, preserves best, and returning home clears the course", () => {
  const model = blank();
  advance(model, 2);
  model.obstacles.push(hazard(160));
  model.tick(1 / 60);
  model.setDucking(true);
  model.bananas = 7;
  const best = model.bestDistance;
  model.begin(42);
  const fresh = new Model(42);
  fresh.begin();
  assert.deepEqual(snapshot(model), snapshot(fresh));
  assert.equal(model.bestDistance, best);
  model.resetToTitle();
  assert.equal(model.phase, "title");
  assert.equal(model.bestDistance, best);
  assert.equal(model._duckHeld, false);
  assert.equal(model.obstacles.length, 0);
});

test("seeded course is identical at 30, 60 and 144 FPS, including after restart", () => {
  const models = [30, 60, 144].map(fps => {
    const model = new Model(77);
    model.begin();
    model.invulnerability = 1000;
    advance(model, 20, 1 / fps);
    return model;
  });
  assert.deepEqual(snapshot(models[0]), snapshot(models[1]));
  assert.deepEqual(snapshot(models[0]), snapshot(models[2]));
  models[0].begin();
  models[0].invulnerability = 1000;
  advance(models[0], 20);
  assert.deepEqual(snapshot(models[0]), snapshot(models[1]));
  const different = new Model(78);
  different.begin();
  different.invulnerability = 1000;
  advance(different, 20);
  assert.notDeepEqual(different.obstacles, models[0].obstacles);
});

test("warm-up precedes hazards and difficulty rises to a bounded speed", () => {
  const model = new Model();
  model.begin();
  advance(model, 0.5);
  assert.equal(model.obstacles.length, 0);
  advance(model, 1);
  assert.equal(model.obstacles[0].kind, "rock");
  assert.ok(model.obstacles[0].x > 400);
  const progression = blank();
  advance(progression, 100);
  assert.equal(progression.speed, 350);
  assert.ok(progression.distance > 1200);
});

test("64 complete generated courses remain traversable with reactive one-action controls", () => {
  for (let seed = 0; seed < 64; seed++) {
    const model = new Model(seed);
    model.begin();
    if (seed >= 32) model.elapsed = 100;
    for (let frame = 0; frame < 60 * 60; frame++) {
      const obstacle = model.obstacles.find(item => item.x + item.width >= model.playerX - 20);
      let slide = false;
      if (obstacle) {
        if (obstacle.kind === "branch") slide = obstacle.x < model.playerX + 110;
        else if (obstacle.x < model.playerX + 20 + model.speed * 0.2 && model.isGrounded()) {
          model.jump();
        }
      }
      model.setDucking(slide);
      model.tick(1 / 60);
    }
    assert.equal(model.lives, 3, `seed ${seed}: no unavoidable encounter`);
    assert.ok(model.bananas > 0, `seed ${seed}: banana trails are reachable`);
    assert.equal(model.phase, "running");
    assert.ok(model.obstacles.length <= 3, "offscreen hazards are removed");
    assert.ok(model.pickups.length <= 9, "offscreen pickups are removed");
  }
});
