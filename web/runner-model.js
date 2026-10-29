/* Songa's scene-independent runner simulation. No DOM, dependencies or modules:
 * usable both in a local file:// HTML page and in the Node regression tests.
 * Geometry/mechanics mirror scripts/runner_model.gd. Distances use 20px/metre.
 * The seeded JS PRNG is stable; it does not reproduce Godot's PCG sequence.
 */
(function (global) {
  "use strict";

  const STEP = 1 / 120;
  const START_SPEED = 240;
  const MAX_SPEED = 350;
  const GRAVITY = 1850;
  const JUMP_SPEED = -680;
  const PLAYER_WIDTH = 40;
  const STANDING_HEIGHT = 80;
  const DUCK_HEIGHT = 32;
  const INVULNERABLE_SECONDS = 1.35;
  const Phase = Object.freeze({
    TITLE: "title", RUNNING: "running", PAUSED: "paused", GAME_OVER: "game_over"
  });

  function intersects(a, b) {
    return a.x < b.x + b.width && a.x + a.width > b.x &&
      a.y < b.y + b.height && a.y + a.height > b.y;
  }

  class RunnerModel {
    constructor(seed = 1308) {
      this.groundY = 740;
      this.playerX = 155;
      this.bestDistance = 0;
      this._runSeed = Number.isFinite(seed) ? seed >>> 0 : 1308;
      this.begin();
      this.phase = Phase.TITLE;
    }

    // Omit the seed to replay this course. Best distance survives restarts.
    begin(seed) {
      if (Number.isFinite(seed) && seed >= 0) this._runSeed = seed >>> 0;
      this._randomState = this._runSeed;
      this.phase = Phase.RUNNING;
      this.distance = 0;
      this.elapsed = 0;
      this.speed = START_SPEED;
      this.playerY = this.groundY;
      this.velocityY = 0;
      this.ducking = false;
      this._duckHeld = false;
      this.lives = 3;
      this.bananas = 0;
      this.hitFlash = 0;
      this.invulnerability = 0;
      this.chasePressure = 0.18;
      this.obstacles = [];
      this.pickups = [];
      this._accumulator = 0;
      this._spawnRemaining = 180;
      this._patternCount = 0;
    }

    resetToTitle() {
      this.begin();
      this.phase = Phase.TITLE;
    }

    togglePause() {
      if (this.phase === Phase.RUNNING) this.phase = Phase.PAUSED;
      else if (this.phase === Phase.PAUSED) this.phase = Phase.RUNNING;
    }

    jump() {
      if (this.phase !== Phase.RUNNING || !this.isGrounded()) return false;
      this.velocityY = JUMP_SPEED;
      this.ducking = false;
      return true;
    }

    setDucking(held) {
      // A release while paused must still clear a held finger/key.
      this._duckHeld = this.phase === Phase.RUNNING && Boolean(held);
      this.ducking = this._duckHeld && this.isGrounded();
    }

    isGrounded() {
      return this.playerY >= this.groundY - 0.01 && this.velocityY >= 0;
    }

    playerRect() {
      const height = this.ducking ? DUCK_HEIGHT : STANDING_HEIGHT;
      return { x: this.playerX - PLAYER_WIDTH / 2, y: this.playerY - height,
        width: PLAYER_WIDTH, height };
    }

    obstacleRect(obstacle) {
      const y = obstacle.y ?? (obstacle.kind === "branch" ?
        this.groundY - 155 : this.groundY - obstacle.height);
      return { x: obstacle.x, y, width: obstacle.width, height: obstacle.height };
    }

    tick(delta) {
      if (this.phase !== Phase.RUNNING || !Number.isFinite(delta) || delta <= 0) return;
      // Avoid catch-up storms after suspended tabs; the UI should also pause on hide.
      this._accumulator += Math.min(delta, 0.25);
      while (this._accumulator + 1e-7 >= STEP && this.phase === Phase.RUNNING) {
        this._accumulator -= STEP;
        this._step();
      }
    }

    _step() {
      this.elapsed += STEP;
      this.speed = Math.min(MAX_SPEED, START_SPEED + this.elapsed * 1.4);
      const movement = this.speed * STEP;
      this.distance += movement / 20;
      this.bestDistance = Math.max(this.bestDistance, this.distance);
      this.hitFlash = Math.max(0, this.hitFlash - STEP);
      this.invulnerability = Math.max(0, this.invulnerability - STEP);
      if (!this.isGrounded()) {
        this.playerY += this.velocityY * STEP + 0.5 * GRAVITY * STEP * STEP;
        this.velocityY += GRAVITY * STEP;
        if (this.playerY >= this.groundY) {
          this.playerY = this.groundY;
          this.velocityY = 0;
        }
      }
      this.ducking = this._duckHeld && this.isGrounded();
      this._spawnRemaining -= movement;
      if (this._spawnRemaining <= 0) this._spawnPattern();

      const body = this.playerRect();
      for (const obstacle of this.obstacles) {
        obstacle.x -= movement;
        if (!obstacle.hit && intersects(body, this.obstacleRect(obstacle))) {
          // Consume even protected encounters, avoiding a delayed or repeated hit.
          obstacle.hit = true;
          if (this.invulnerability <= 0) this._takeHit();
        }
        if (obstacle.x + obstacle.width < this.playerX - PLAYER_WIDTH / 2) {
          obstacle.passed = true;
        }
      }
      for (const pickup of this.pickups) {
        pickup.x -= movement;
        if (!pickup.collected && pickup.x >= body.x - 10 &&
            pickup.x < body.x + body.width + 10 && pickup.y >= body.y - 10 &&
            pickup.y < body.y + body.height + 10) {
          pickup.collected = true;
          this.bananas += 1;
        }
      }
      this.obstacles = this.obstacles.filter(item => item.x + item.width > -80);
      this.pickups = this.pickups.filter(item => item.x > -40 && !item.collected);
      this.chasePressure = Math.min(0.92,
        Math.max(0.18, 0.18 + (3 - this.lives) * 0.27 + this.elapsed * 0.0007));
    }

    _takeHit() {
      this.lives -= 1;
      this.hitFlash = 0.45;
      this.invulnerability = INVULNERABLE_SECONDS;
      if (this.lives <= 0) {
        this.lives = 0;
        this.phase = Phase.GAME_OVER;
        this._duckHeld = false;
        this.ducking = false;
      }
    }

    _random() {
      // Mulberry32, with explicit unsigned state including the valid zero seed.
      this._randomState = (this._randomState + 0x6d2b79f5) >>> 0;
      let value = this._randomState;
      value = Math.imul(value ^ (value >>> 15), value | 1);
      value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
      return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
    }

    _spawnPattern() {
      // A predictable introductory rock/log/branch sequence teaches each action.
      const kinds = ["rock", "log", "branch"];
      const kind = this._patternCount < 3 ? kinds[this._patternCount] :
        kinds[Math.floor(this._random() * kinds.length)];
      const width = kind === "rock" ? 42 : kind === "log" ? 64 : 74;
      const height = kind === "rock" ? 48 : kind === "log" ? 38 : 105;
      const y = this.groundY - (kind === "branch" ? 155 : height);
      const x = 640;
      this.obstacles.push({ x, y, width, height, kind, passed: false, hit: false });
      for (let index = 0; index < 3; index += 1) {
        const pickupY = kind === "branch" ? this.groundY - 18 :
          this.groundY - 110 - (index === 1 ? 25 : 0);
        this.pickups.push({ x: x - 36 + index * 36, y: pickupY, collected: false });
      }
      // Enough space to land, release a slide and react even at maximum speed.
      this._spawnRemaining += this.speed * (1.9 + this._random() * 0.6) + width;
      this._patternCount += 1;
    }
  }

  RunnerModel.Phase = Phase;
  RunnerModel.STEP = STEP;
  RunnerModel.START_SPEED = START_SPEED;
  RunnerModel.MAX_SPEED = MAX_SPEED;
  global.SongaRunnerModel = RunnerModel;
})(globalThis);
