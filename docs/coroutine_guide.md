# Coroutine System — Implementation Guide

> This guide is written for your specific codebase.  
> It assumes you have never used coroutines before.  
> **Do not edit any files until you understand the concept sections.**

---

## Part 1 — What is a coroutine and why do you care?

A normal function runs from top to bottom and returns once.  
A coroutine is a function that can **pause itself mid-execution and resume later**.

```lua
-- Normal function: runs all at once
local function shoot3Times()
    fire()
    fire()
    fire()
    -- all 3 happen in the same frame
end

-- Coroutine: can wait between each shot
local function shoot3Times(self)
    fire()
    self.wait(0.5)   -- pause for 0.5 seconds, then resume
    fire()
    self.wait(0.5)
    fire()
end
```

This is exactly what your step-table system was trying to do — but coroutines let you write it as **plain readable code** instead of a data table that an interpreter has to decode.

---

## Part 2 — How coroutines work in Lua (the basics)

There are only 3 things you need to know:

```lua
-- 1. Create a coroutine from a function
local co = coroutine.create(myFunction)

-- 2. Resume it (runs the function until it hits a yield)
coroutine.resume(co)

-- 3. Inside the function, yield pauses it
coroutine.yield()
```

Example:
```lua
local function example()
    print("A")
    coroutine.yield()   -- pause here
    print("B")
    coroutine.yield()   -- pause here
    print("C")
end

local co = coroutine.create(example)

coroutine.resume(co)   -- prints "A"
coroutine.resume(co)   -- prints "B"
coroutine.resume(co)   -- prints "C"
-- coroutine is now dead (function returned)
```

**Key insight**: `coroutine.yield()` can pass a value back to whoever called `resume`:

```lua
local function example()
    coroutine.yield(0.5)   -- "wait 0.5 seconds before resuming me"
end

local co = coroutine.create(example)
local ok, waitTime = coroutine.resume(co)
-- ok = true, waitTime = 0.5
```

This is how the timing system works: the coroutine says *how long to wait*, and the engine respects that.

---

## Part 3 — The two new files you need to create

### `src/tasks/task.lua`

This is the lowest-level piece. It wraps a coroutine and tracks how long to wait before resuming it.

```lua
-- src/tasks/task.lua
local task = {}

function task.new(fn, env)
    local t = {
        co       = coroutine.create(fn),
        waitLeft = 0,     -- seconds left before next resume
        dead     = false,
        env      = env or {},
    }

    -- self.wait(seconds) is what task functions call to pause themselves
    function t.wait(seconds)
        coroutine.yield(seconds or 0)
    end

    -- Run the coroutine once immediately so it reaches its first yield
    coroutine.resume(t.co, t, env)

    return t
end

function task.update(t, dt)
    if t.dead then return end

    t.waitLeft = t.waitLeft - dt

    if t.waitLeft <= 0 then
        local ok, result = coroutine.resume(t.co)
        if not ok or coroutine.status(t.co) == "dead" then
            t.dead = true
        else
            t.waitLeft = result or 0   -- result is what the coroutine yielded
        end
    end
end

return task
```

**Reading it**:
- `task.new(fn, env)` creates the task and runs it to its first yield
- `task.update(t, dt)` is called every frame; it counts down `waitLeft` and resumes when ready
- When the function returns (coroutine is "dead"), `t.dead` becomes `true`

---

### `src/tasks/scheduler.lua`

One entity (enemy, boss) can have multiple tasks running at the same time — one for movement, one for attacks. The scheduler manages that list.

```lua
-- src/tasks/scheduler.lua
local task = require("src.tasks.task")
local scheduler = {}

function scheduler.new()
    local s = { tasks = {} }

    -- Add a new concurrent task
    function s:add(fn, env)
        table.insert(self.tasks, task.new(fn, env))
    end

    -- Kill all tasks (useful if you want to hard-reset an enemy)
    function s:clear()
        self.tasks = {}
    end

    -- Call this every frame
    function s:update(dt)
        for i = #self.tasks, 1, -1 do
            local t = self.tasks[i]
            t.env.dt = dt              -- inject dt so tasks can use it
            task.update(t, dt)
            if t.dead then
                table.remove(self.tasks, i)
            end
        end
    end

    return s
end

return scheduler
```

**Reading it**:
- `s:add(fn, env)` spawns a new coroutine task
- `s:update(dt)` ticks all tasks, removes finished ones
- `t.env.dt = dt` — this is how tasks get access to `dt` (explained in Part 5)

---

## Part 4 — Updating `enemy.lua`

### In `enemy.spawn`:

Remove these old fields from the entity table `e = { ... }`:
```lua
-- DELETE these:
moveScript  = param.moveScript or {},
movePattern = param.movePattern,
moveStep    = 1,
attackScript = param.attackScript or {},
attackStep  = 1,
```

Add this at the top of `enemy.lua` (with the other requires):
```lua
local scheduler = require("src.tasks.scheduler")
```

Add a scheduler to the entity table and also add `_player` to the dependencies:
```lua
-- ADD inside `e = { ... }`:
scheduler = scheduler.new(),
```

Then, after creating `e` but before `table.insert(enemyList, e)`, launch the tasks:
```lua
if param.moveScript then
    e.scheduler:add(param.moveScript, { enemy = e })
end
if param.attackScript then
    e.scheduler:add(param.attackScript, {
        enemy = e,
        shoot = function(pattern, props)
            _patterns[pattern](e, _player, props)
        end,
    })
end
```

For `shoot` and `_patterns` to work here, `enemy.init` needs to also accept `player` and `patterns` as dependencies. Add them:

```lua
-- In enemy.init(deps):
_patterns = deps.patterns
_player   = deps.player
```

And wire them in `modules.lua`:
```lua
-- In mod.enemy.init({ ... }):
patterns = mod.patterns,
player   = mod.player,
```

### In `enemy.update`:

Replace:
```lua
_bossPhase.update(e)
_movement.update(dt, e)
_attack.update(dt, e)
```

With:
```lua
e.scheduler:update(dt)
```

That's it. One line instead of three.

---

## Part 5 — Rewriting `movement.lua`

The old `movement.lua` was an interpreter that read step tables.  
The new one is just a library of helper functions that coroutines call.

```lua
-- src/entities/enemies/behaviors/movement.lua
local movement = {}

-- Move an enemy toward (tx, ty) at the given speed.
-- Yields every frame until it arrives.
function movement.to(self, env, tx, ty, speed)
    local e = env.enemy
    while true do
        local dx   = tx - e.x
        local dy   = ty - e.y
        local dist = math.sqrt(dx * dx + dy * dy)
        if dist <= 1 then break end
        e.x = e.x + (dx / dist) * speed * env.dt
        e.y = e.y + (dy / dist) * speed * env.dt
        self.wait(0)   -- 0 = "resume me next frame"
    end
end

-- Move along a bezier curve over `duration` seconds.
function movement.curve(self, env, ctrlX, ctrlY, tx, ty, duration)
    local e       = env.enemy
    local curve   = love.math.newBezierCurve(e.x, e.y, ctrlX, ctrlY, tx, ty)
    local elapsed = 0
    while elapsed < duration do
        elapsed = elapsed + env.dt
        local t = math.min(1, elapsed / duration)
        e.x, e.y = curve:evaluate(t)
        self.wait(0)
    end
end

return movement
```

**No `update()` function. No step table. Just helpers.**

> `env.dt` is available because `scheduler:update` injects it every frame (see Part 3).

---

## Part 6 — Rewriting `attack.lua`

The old `attack.lua` was also an interpreter. The new one just holds its `init`:

```lua
-- src/entities/enemies/behaviors/attack.lua
local attack = {}
local _patterns, _player

function attack.init(deps)
    _patterns = deps.patterns
    _player   = deps.player
end

return attack
```

The actual shooting logic now lives inside the `attackScript` function in the stage file.  
The `shoot` helper is built directly in `enemy.spawn` (see Part 4), so `attack.lua` itself doesn't need to do anything else.

You can also **delete `bossPhase.lua` entirely**. Boss phases are handled by the coroutine (see Part 7).

---

## Part 7 — What stage files look like now

### Regular enemies

Old (step table):
```lua
{
    type = "ghost", health = 1, hitboxR = 10, x = 320, y = -50,
    moveScript = {
        { action = "moveTo", targetX = 320, targetY = 120, speed = 80 },
        { action = "wait", duration = 3 },
        { action = "moveTo", targetX = 640, targetY = 120, speed = 80 },
    },
    attackScript = {
        { action = "shoot", pattern = "aim", props = { bulletType = "objects_r5i1", speed = 200 } },
        { action = "wait", duration = 0.3 },
        { action = "repeat", targetStep = 1 },
    },
}
```

New (functions):
```lua
local move = require("src.entities.enemies.behaviors.movement")

{
    type = "ghost", health = 1, hitboxR = 10, x = 320, y = -50,

    moveScript = function(self, env)
        move.to(self, env, 320, 120, 80)
        self.wait(3)
        move.to(self, env, 640, 120, 80)
        -- function ends: task dies, enemy just stops moving
    end,

    attackScript = function(self, env)
        while true do
            env.shoot("aim", { bulletType = "objects_r5i1", speed = 200 })
            self.wait(0.3)
        end
    end,
}
```

The attack loop runs forever (`while true`) — that's fine because when the enemy dies, the scheduler is gone with it.

---

### Boss with phases

Old (separate bossPhases table + external watcher):
```lua
bossPhases = {
    { trigger = { hp = 0.75 }, moveScript = { ... }, attackScript = { ... } },
    { trigger = { hp = 0.40 }, moveScript = { ... }, attackScript = { ... } },
}
```

New (phases are just `if` checks inside the coroutine — no bossPhases table):
```lua
{
    type = "tank", isBoss = true, health = 300, maxHealth = 300,
    hitboxR = 25, x = 320, y = -80,

    moveScript = function(self, env)
        local e = env.enemy
        move.to(self, env, 320, 80, 80)   -- enter from top
        while true do
            if e.health <= e.maxHealth * 0.40 then
                -- phase 3: erratic movement
                move.to(self, env, math.random(100, 540), math.random(60, 180), 120)
                self.wait(0.05)
            else
                self.wait(0.5)
            end
        end
    end,

    attackScript = function(self, env)
        local e = env.enemy
        while true do
            if e.health > e.maxHealth * 0.75 then
                -- phase 1: calm
                env.shoot("fan", { bulletType = "objects_r4i5", speed = 200, count = 5, spread = 0.25 })
                self.wait(0.6)
            elseif e.health > e.maxHealth * 0.40 then
                -- phase 2: faster
                env.shoot("fan", { bulletType = "objects_r4i5", speed = 220, count = 7, spread = 0.20 })
                self.wait(0.45)
            else
                -- phase 3: enrage
                env.shoot("fan", { bulletType = "objects_r5i1", speed = 260, count = 9, spread = 0.18 })
                self.wait(0.35)
            end
        end
    end,
}
```

No `bossPhases` table. No external watcher. The coroutine checks HP every loop and adjusts naturally.

---

### Stage script

Old (time-keyed list):
```lua
stage1.script = {
    { time = 0,  action = "bg",    map = stage1.bg.default, scrollSpeed = 30 },
    { time = 3,  action = "spawn", enemies = stage1.wave1 },
    { time = 15, action = "spawn", enemies = stage1.boss },
    ...
}
```

New (a plain function):
```lua
stage1.script = function(s)
    s.bg("src/maps/stage1/stage1.png", 30)
    s.music("stage1")

    s.wait(3)
    s.spawn(stage1.wave1)

    s.wait(3)
    s.spawn(stage1.wave2)

    s.waitUntilClear()   -- blocks here until all enemies are dead

    s.clearEnemies()
    s.clearBullets()
    s.flash(1)
    s.wait(0.5)

    s.music("boss1")
    s.bg("src/maps/stage1/boss1.png", 0)
    s.spawn(stage1.boss)

    s.waitUntilClear()
    -- function returns = stage is done
end
```

`s.waitUntilClear()` is the big win here — it properly blocks until enemies are dead.  
The old system had to guess the timing with hardcoded `time` values.

---

## Part 8 — Rewriting `script.lua`

The old `script.lua` advanced through a time-keyed event list.  
The new one runs a stage function as a coroutine.

```lua
-- src/stageCtrl/script.lua
local script = {}
local _enemy, _audio, _bg, _shader, _bullet

function script.init(deps)
    _enemy  = deps.enemy
    _audio  = deps.audio
    _bg     = deps.bg
    _shader = deps.shader
    _bullet = deps.bullet
end

local co        = nil
local waitLeft  = 0
local stageDone = false

function script.load(fn)
    stageDone = false
    waitLeft  = 0
    co = coroutine.create(fn)

    -- This is the API the stage script receives as `s`
    local api = {
        wait = function(seconds)
            coroutine.yield(seconds)
        end,
        waitUntilClear = function()
            while not _enemy.allDead() do
                coroutine.yield(0)
            end
        end,
        spawn        = function(list)        for _, e in ipairs(list) do _enemy.spawn(e) end end,
        music        = function(track)       _audio.playBGM(_audio.bgm[track]) end,
        bg           = function(map, speed)  _bg.load(map, true);  _bg.setScrollSpeed(speed) end,
        altbg        = function(map, speed)  _bg.load(map, false); _bg.setScrollSpeed(speed) end,
        flash        = function(d)           _shader.flashStart(d) end,
        clearEnemies = function()            _enemy.clearCurrent("script") end,
        clearBullets = function()            _bullet.clear() end,
    }

    coroutine.resume(co, api)   -- run until first yield
end

function script.allDone()
    return stageDone and _enemy.allDead()
end

function script.update(dt)
    if not co or stageDone then return end
    waitLeft = waitLeft - dt
    if waitLeft <= 0 then
        local ok, result = coroutine.resume(co)
        if not ok or coroutine.status(co) == "dead" then
            stageDone = true
        else
            waitLeft = result or 0
        end
    end
end

return script
```

**Nothing in `stages.lua` needs to change.** It already passes `stage.script` to `script.load()` — now that value is just a function instead of a table.

---

## Part 9 — Updating `enemyTimer.lua`

Remove the `move` and `attack` timers:

```lua
-- Before:
function enemyTimer.load()
    return {
        flash  = timer.load({ duration = 0.05 }),
        move   = timer.load({}),
        attack = timer.load({}),
    }
end

-- After:
function enemyTimer.load()
    return {
        flash = timer.load({ duration = 0.05 }),
    }
end
```

---

## Part 10 — Cleaning up `modules.lua`

```lua
-- DELETE from the require block:
movement  = require("src.entities.enemies.behaviors.movement"),
bossPhase = require("src.entities.enemies.behaviors.bossPhase"),

-- DELETE from mod.enemy.init({ ... }):
movement  = mod.movement,
bossPhase = mod.bossPhase,

-- ADD to mod.enemy.init({ ... }):
patterns  = mod.patterns,
player    = mod.player,
```

`attack` stays — it still needs `init()` for its own internal use.  
`movement` is now a stateless helper — stage files require it directly, no wiring needed.

---

## Implementation order (recommended)

Do these one at a time and test after each step:

| # | File | What you do |
|---|------|-------------|
| 1 | `src/tasks/task.lua` | Create (new file) |
| 2 | `src/tasks/scheduler.lua` | Create (new file) |
| 3 | `src/stageCtrl/script.lua` | Full rewrite |
| 4 | `src/entities/enemies/behaviors/movement.lua` | Full rewrite |
| 5 | `src/entities/enemies/behaviors/attack.lua` | Full rewrite |
| 6 | `src/entities/enemies/enemy.lua` | Update spawn + update |
| 7 | `src/timers/enemyTimer.lua` | Remove move/attack timers |
| 8 | `src/entities/enemies/behaviors/bossPhase.lua` | Delete file |
| 9 | `src/modules.lua` | Remove old wiring, add new |
| 10 | `src/stages/stage1.lua` | Convert scripts to functions |
| 11 | `src/stages/stage2.lua` | Convert scripts to functions |

---

## Quick reference — things you write in stage files

```lua
local move = require("src.entities.enemies.behaviors.movement")

-- Wait N seconds
self.wait(2)

-- Move to a position (blocks until arrived)
move.to(self, env, targetX, targetY, speed)

-- Move along a curve
move.curve(self, env, ctrlX, ctrlY, targetX, targetY, duration)

-- Shoot a pattern
env.shoot("patternName", { ...props... })

-- Attack loop (runs forever until enemy dies)
while true do
    env.shoot("fan", props)
    self.wait(0.4)
end

-- Boss phase check inside a loop
while true do
    if e.health > e.maxHealth * 0.50 then
        env.shoot("aim", propsPhase1)
        self.wait(0.5)
    else
        env.shoot("spiral", propsPhase2)
        self.wait(0.3)
    end
end
```
