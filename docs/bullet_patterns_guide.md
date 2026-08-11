# Bullet Pattern Design — From Scratch

> A beginner's guide. No prior experience assumed.  
> All code is in Lua but the concepts apply to any language.

---

## Table of Contents

1. [The one function you need](#1-the-one-function-you-need)
2. [The math — angles and directions](#2-the-math--angles-and-directions)
3. [Pattern 1 — Single aimed shot](#3-pattern-1--single-aimed-shot)
4. [Pattern 2 — Fixed direction shot](#4-pattern-2--fixed-direction-shot)
5. [Pattern 3 — Fan / spread](#5-pattern-3--fan--spread)
6. [Pattern 4 — Ring](#6-pattern-4--ring)
7. [Pattern 5 — Spiral](#7-pattern-5--spiral)
8. [Pattern 6 — Multi-arm spiral](#8-pattern-6--multi-arm-spiral)
9. [Pattern 7 — Spray (randomized)](#9-pattern-7--spray-randomized)
10. [Pattern 8 — Burst (time-based)](#10-pattern-8--burst-time-based)
11. [Combining patterns](#11-combining-patterns)
12. [Design tips and feel](#12-design-tips-and-feel)

---

## 1. The one function you need

Every bullet pattern boils down to one thing:

> **Fire a bullet from position (x, y), moving in a direction.**

In your game, that call looks like this:

```lua
spawnBullet(x, y, velX, velY)
```

- `x, y` — where the bullet starts (usually the enemy's center)
- `velX` — how many pixels per second the bullet moves horizontally
- `velY` — how many pixels per second the bullet moves vertically

Every pattern in this guide is just **deciding what `velX` and `velY` to pass**.  
That's the whole job.

---

## 2. The math — angles and directions

### What is an angle?

An angle describes **which direction** something is pointing.  
Your game uses **radians**, not degrees. Here's the full picture:

```
              -π/2
               ↑
               │
    π ←────── [0,0] ──────→ 0
               │
               ↓
              +π/2
```

| Angle (radians) | Direction |
|---|---|
| `0` | Right → |
| `math.pi / 2` ≈ 1.57 | Down ↓ |
| `math.pi` ≈ 3.14 | Left ← |
| `-math.pi / 2` ≈ -1.57 | Up ↑ |
| `2 * math.pi` ≈ 6.28 | Full circle (same as 0) |

> **Why radians?** Because Lua's `math.sin` and `math.cos` use them.
> If you prefer degrees, convert with: `radians = degrees * (math.pi / 180)`

---

### Turning an angle into velX and velY

This is **the most important formula in this guide**. Read it slowly.

```lua
velX = math.cos(angle) * speed
velY = math.sin(angle) * speed
```

`math.cos` gives the horizontal component. `math.sin` gives the vertical.  
Multiply both by `speed` to control how fast the bullet travels.

**Examples:**
```lua
-- Shoot right at speed 200
velX = math.cos(0) * 200        -- cos(0) = 1.0  → velX = 200
velY = math.sin(0) * 200        -- sin(0) = 0.0  → velY = 0

-- Shoot downward at speed 200
velX = math.cos(math.pi/2) * 200   -- cos(π/2) = 0.0  → velX = 0
velY = math.sin(math.pi/2) * 200   -- sin(π/2) = 1.0  → velY = 200

-- Shoot diagonally (down-right) at speed 200
-- angle = π/4 (45 degrees)
velX = math.cos(math.pi/4) * 200   -- ≈ 141
velY = math.sin(math.pi/4) * 200   -- ≈ 141
```

> **Key insight:** `cos` and `sin` always give values between -1 and +1.
> They describe a *direction* (unit vector). Multiplying by speed scales it.

From this point on, you'll always write:
```lua
local velX = math.cos(angle) * speed
local velY = math.sin(angle) * speed
spawnBullet(x, y, velX, velY)
```

---

### Getting the angle toward a target

One more formula you'll use constantly:

```lua
local angle = math.atan2(targetY - fromY, targetX - fromX)
```

`math.atan2(dy, dx)` returns the angle from one point to another.  
**Note: `dy` comes first** — this is a common mistake to make.

```lua
-- Angle from enemy to player:
local angle = math.atan2(player.y - enemy.y, player.x - enemy.x)
```

---

## 3. Pattern 1 — Single aimed shot

The simplest possible pattern. One bullet aimed at the player.

```lua
local function shootAimed(ex, ey, tx, ty, speed)
    -- ex, ey = enemy position
    -- tx, ty = target (player) position
    local angle = math.atan2(ty - ey, tx - ex)
    local velX  = math.cos(angle) * speed
    local velY  = math.sin(angle) * speed
    spawnBullet(ex, ey, velX, velY)
end
```

**Visual:**
```
  [E]
   │
   ▼  ← one bullet
  [P]
```

**Usage:**
```lua
shootAimed(enemy.x, enemy.y, player.x, player.y, 200)
```

**Variations:**
```lua
-- Shoot slightly to the left of the player (offset angle by 0.1 rad)
local angle = math.atan2(ty - ey, tx - ex) + 0.1

-- Shoot in two directions: slightly left AND right of the player
local angle = math.atan2(ty - ey, tx - ex)
spawnBullet(ex, ey, math.cos(angle - 0.1) * speed, math.sin(angle - 0.1) * speed)
spawnBullet(ex, ey, math.cos(angle + 0.1) * speed, math.sin(angle + 0.1) * speed)
```

---

## 4. Pattern 2 — Fixed direction shot

A bullet that always goes in the same direction, regardless of the player.  
Good for stage hazards, patterned volleys, or downward rain.

```lua
local function shootDown(ex, ey, speed)
    local angle = math.pi / 2   -- straight down
    local velX  = math.cos(angle) * speed   -- = 0
    local velY  = math.sin(angle) * speed   -- = speed
    spawnBullet(ex, ey, velX, velY)
end
```

You can use any hardcoded angle:
```lua
math.pi / 2           -- straight down
-math.pi / 2          -- straight up
0                     -- straight right
math.pi               -- straight left
math.pi / 4           -- diagonal down-right (45°)
math.pi * 3 / 4       -- diagonal down-left (135°)
```

---

## 5. Pattern 3 — Fan / spread

Fire multiple bullets in a fan shape around a center angle.

**The idea:**  
Pick a center angle (e.g. aimed at player). Spread N bullets evenly around it.

```lua
local function shootFan(ex, ey, tx, ty, speed, count, spread)
    -- count  = number of bullets
    -- spread = total angle of the fan in radians (e.g. 0.8 = about 45°)

    local centerAngle = math.atan2(ty - ey, tx - ex)

    for i = 0, count - 1 do
        -- Evenly distribute bullets across the spread
        -- When i = 0:            angle = centerAngle - spread/2  (left edge)
        -- When i = count-1:      angle = centerAngle + spread/2  (right edge)
        -- When i = (count-1)/2:  angle = centerAngle             (center)
        local t     = count == 1 and 0.5 or (i / (count - 1))
        local angle = centerAngle + (t - 0.5) * spread

        spawnBullet(ex, ey, math.cos(angle) * speed, math.sin(angle) * speed)
    end
end
```

**Visual (count=5, aimed down):**
```
  [E]
 ↙↓↓↓↘
```

**Usage:**
```lua
shootFan(enemy.x, enemy.y, player.x, player.y, 200, 5, 0.8)
--                                                   ↑  ↑
--                                                count spread (radians)
```

**`spread` reference:**
| Value | Visual feel |
|---|---|
| `0.2` | Very tight, almost a triple-shot |
| `0.5` | Comfortable fan, about 28° total |
| `math.pi / 2` | Wide 90° fan |
| `math.pi` | 180° wall |

---

## 6. Pattern 4 — Ring

Fire bullets in all directions equally. No aiming.

**The idea:**  
Divide the full circle (`2π`) by the bullet count to get the step between each.

```lua
local function shootRing(ex, ey, speed, count, angleOffset)
    -- angleOffset (optional) rotates the whole ring
    angleOffset = angleOffset or 0

    local step = (2 * math.pi) / count

    for i = 0, count - 1 do
        local angle = angleOffset + i * step
        spawnBullet(ex, ey, math.cos(angle) * speed, math.sin(angle) * speed)
    end
end
```

**Visual (count=8):**
```
  ↑
↖ │ ↗
← [E] →
↙ │ ↘
  ↓
```

**Usage:**
```lua
shootRing(enemy.x, enemy.y, 160, 8)         -- 8-bullet ring
shootRing(enemy.x, enemy.y, 160, 8, 0.3)    -- same ring, rotated by 0.3 rad
```

**`angleOffset` is powerful** — by changing it each call you can rotate the
ring over time (this becomes a spiral, covered next).

---

## 7. Pattern 5 — Spiral

A spiral is just a **ring where `angleOffset` increases every call**.  
Each time the pattern fires, the ring has rotated a little further.

```lua
-- Store this in the enemy's data — it must persist between calls
local spiralAngle = 0

local function shootSpiral(ex, ey, speed, count, rotationSpeed)
    -- rotationSpeed = how many radians to rotate per call
    local step = (2 * math.pi) / count

    for i = 0, count - 1 do
        local angle = spiralAngle + i * step
        spawnBullet(ex, ey, math.cos(angle) * speed, math.sin(angle) * speed)
    end

    spiralAngle = spiralAngle + rotationSpeed
end
```

**What happens frame by frame:**
```
Call 1 (angle=0.00): → ↑ ← ↓
Call 2 (angle=0.15):  ↗ ↖ ↙ ↘
Call 3 (angle=0.30): ↑ ← ↓ →
... (keeps rotating)
```

**In practice — storing state on the enemy:**
```lua
-- When the enemy is created:
enemy.spiralAngle = 0

-- In the attack function:
local function shootSpiral(ex, ey, speed, count, enemy)
    local step = (2 * math.pi) / count
    for i = 0, count - 1 do
        local angle = enemy.spiralAngle + i * step
        spawnBullet(ex, ey, math.cos(angle) * speed, math.sin(angle) * speed)
    end
    enemy.spiralAngle = enemy.spiralAngle + 0.15   -- advance each call
end
```

**`rotationSpeed` reference:**
| Value | Feel |
|---|---|
| `0.05` | Very slow, hypnotic rotation |
| `0.15` | Default, satisfying spin |
| `0.4` | Fast, dizzying |

---

## 8. Pattern 6 — Multi-arm spiral

Instead of evenly spacing all bullets across `2π`, you group them into "arms"
that are offset from each other.

**One-arm:** fires 1 bullet per call, advances angle.  
**Two-arm:** fires 2 bullets per call, exactly `π` apart.  
**N-arm:** fires N bullets per call, each `2π/N` apart.

```lua
local function shootMultiArmSpiral(ex, ey, speed, arms, enemy)
    local armSpacing = (2 * math.pi) / arms   -- angle between arms

    for i = 0, arms - 1 do
        local angle = enemy.spiralAngle + i * armSpacing
        spawnBullet(ex, ey, math.cos(angle) * speed, math.sin(angle) * speed)
    end

    enemy.spiralAngle = enemy.spiralAngle + 0.1   -- rotate each call
end
```

**Visual — 3-arm spiral:**
```
Call 1:          Call 2:          Call 3:
    ↑                ↖               ←
  [E]             [E]             [E]
↙     ↘         ↙     ↓         ↓     ↗
```

The three arms always stay `120°` (`2π/3`) apart from each other, and the
whole formation rotates each call.

**Usage:**
```lua
-- Two-arm (pinwheel):
shootMultiArmSpiral(enemy.x, enemy.y, 160, 2, enemy)

-- Three-arm (trefoil):
shootMultiArmSpiral(enemy.x, enemy.y, 160, 3, enemy)

-- Six-arm (dense star):
shootMultiArmSpiral(enemy.x, enemy.y, 160, 6, enemy)
```

---

## 9. Pattern 7 — Spray (randomized)

Fire bullets at random angles within a cone. Feels organic and chaotic.

```lua
local function shootSpray(ex, ey, tx, ty, speed, count, coneAngle)
    -- coneAngle = total width of the random cone (e.g. math.pi = 180°)
    local center = math.atan2(ty - ey, tx - ex)

    for i = 1, count do
        -- math.random() gives [0, 1]
        -- math.random() * 2 - 1 gives [-1, +1]
        -- multiply by coneAngle/2 to get within ±halfCone of center
        local angle = center + (math.random() * 2 - 1) * (coneAngle / 2)

        -- Optional: randomize speed slightly so bullets don't overlap
        local s = speed * (0.85 + math.random() * 0.3)

        spawnBullet(ex, ey, math.cos(angle) * s, math.sin(angle) * s)
    end
end
```

**Visual (count=8, wide cone):**
```
  [E]
↙↙↓↓↓↓↘↘  (random, each call looks different)
```

**Usage:**
```lua
-- Tight shotgun blast at player
shootSpray(enemy.x, enemy.y, player.x, player.y, 220, 8, 0.4)

-- Wild chaos spray in a 120° cone
shootSpray(enemy.x, enemy.y, player.x, player.y, 180, 12, math.pi * 2/3)
```

---

## 10. Pattern 8 — Burst (time-based)

A burst fires several bullets in sequence with a short delay between each.  
This is **not a single-call pattern** — it requires coroutines or a timer.

With your coroutine system (`self.wait`):

```lua
attackScript = function(self, env)
    while true do
        -- Take aim once at the start of the burst
        local angle = math.atan2(
            player.y - env.enemy.y,
            player.x - env.enemy.x
        )

        -- Fire 3 bullets in rapid sequence
        for i = 1, 3 do
            local velX = math.cos(angle) * 220
            local velY = math.sin(angle) * 220
            spawnBullet(env.enemy.x, env.enemy.y, velX, velY)
            self.wait(0.07)   -- tiny gap between bullets
        end

        self.wait(0.8)   -- longer gap before next burst
    end
end
```

**Visual (time flows down):**
```
t=0.00  ●   ← bullet 1
t=0.07  ●   ← bullet 2 (same direction)
t=0.14  ●   ← bullet 3
t=0.94  ●   ← burst 2 begins
...
```

**Why this feels different from a fan:**  
A fan fires 3 bullets in *different directions* at the same time.  
A burst fires 3 bullets in the *same direction* with gaps — they chase each other.

---

## 11. Combining patterns

The most interesting attacks come from **mixing patterns over time**.

### Example — Classic boss rotation

```lua
attackScript = function(self, env)
    -- Phase A: spiral for 3 seconds
    env.enemy.spiralAngle = 0
    for i = 1, 30 do
        shootMultiArmSpiral(env.enemy.x, env.enemy.y, 150, 3, env.enemy)
        self.wait(0.1)
    end

    -- Brief pause (the "breath")
    self.wait(0.4)

    -- Phase B: aimed fan burst
    for i = 1, 5 do
        shootFan(env.enemy.x, env.enemy.y, player.x, player.y, 240, 7, 0.6)
        self.wait(0.2)
    end

    self.wait(0.6)
    -- repeat
end
```

### Example — Alternating ring + aim

```lua
attackScript = function(self, env)
    while true do
        -- Slow ring
        shootRing(env.enemy.x, env.enemy.y, 120, 12)
        self.wait(0.3)

        -- Fast aimed shot
        shootAimed(env.enemy.x, env.enemy.y, player.x, player.y, 280)
        self.wait(0.5)
    end
end
```

---

## 12. Design tips and feel

### The three levers

Every pattern has three things you can tune:

| Lever | What it changes |
|---|---|
| **Count** | How dense the pattern looks |
| **Speed** | How dangerous / urgent it feels |
| **Timing** (`self.wait`) | The rhythm and breathing room |

Adjust these before inventing a new pattern type — they have more impact than
you'd expect.

---

### Speed vs count tradeoff

- **More bullets, slower speed** → walls of bullets that feel claustrophobic
- **Fewer bullets, faster speed** → sniper-like, requires precise dodging
- **Many bullets, fast speed** → overwhelming, use sparingly (boss enrage)

---

### The "tell" principle

A fair pattern gives the player a **signal** before it fires.  
The simplest tell is a pause:

```lua
self.wait(0.5)   -- enemy "winds up"
shootRing(...)   -- then fires
self.wait(1.2)   -- recovery
```

You can also build up to a pattern:
```lua
-- Start slow, get faster (player learns the pattern, then it escalates)
for interval = 0.8, 0.2, -0.15 do
    shootFan(...)
    self.wait(interval)
end
```

---

### Boss phases

Change parameters based on health percentage:

```lua
attackScript = function(self, env)
    while true do
        local e = env.enemy
        local hp = e.health / e.maxHealth   -- 0.0 to 1.0

        if hp > 0.6 then
            -- Phase 1: calm
            shootFan(e.x, e.y, player.x, player.y, 180, 5, 0.5)
            self.wait(0.8)
        elseif hp > 0.3 then
            -- Phase 2: faster, more bullets
            shootFan(e.x, e.y, player.x, player.y, 220, 7, 0.45)
            self.wait(0.55)
        else
            -- Phase 3: enrage — spiral + aimed at same time
            shootMultiArmSpiral(e.x, e.y, 200, 2, e)
            shootAimed(e.x, e.y, player.x, player.y, 280)
            self.wait(0.12)
        end
    end
end
```

---

### Pattern design checklist

Before finishing a pattern, ask:
- [ ] Can the player actually dodge it with skill?
- [ ] Is there a tell before the dangerous part?
- [ ] Does it get more interesting over time, or does it repeat mindlessly?
- [ ] Does it feel different from the other patterns in this fight?

---

## Quick reference

```
spawnBullet(x, y, velX, velY)
    └── velX = cos(angle) * speed
    └── velY = sin(angle) * speed

angle = math.atan2(dy, dx)   ← from point A to point B
                     ↑↑
              targetY - fromY, targetX - fromX

Full circle  = 2 * math.pi ≈ 6.28
Half circle  = math.pi     ≈ 3.14
Quarter      = math.pi / 2 ≈ 1.57

Ring step between N bullets = (2 * math.pi) / N

Fan offset for bullet i (of count):
    t = i / (count - 1)          ← 0.0 to 1.0
    angle = center + (t - 0.5) * totalSpread
```

---

## Summary — patterns at a glance

| Pattern | What makes it | Key idea |
|---|---|---|
| Aimed shot | `atan2` → one bullet | single direction |
| Fixed shot | hardcoded angle | same direction always |
| Fan | `atan2` + loop over offset angles | spread around center |
| Ring | loop `i * (2π / count)` | equal spacing, full circle |
| Spiral | ring + increment `angleOffset` each call | rotation over time |
| Multi-arm | spiral + `arms` bullets per call | multiple streams |
| Spray | random angle within cone | organic chaos |
| Burst | loop + `self.wait` between shots | sequential timing |
