# Movement Pattern Design — From Scratch

> A beginner's guide. No prior experience assumed.  
> This guide is tailored to the coroutine (`env.wait`) system your game uses.

---

## Table of Contents

1. [The one rule of movement](#1-the-one-rule-of-movement)
2. [The math — distance and direction](#2-the-math--distance-and-direction)
3. [Pattern 1 — Simple move to point](#3-pattern-1--simple-move-to-point)
4. [Pattern 2 — Move for a duration](#4-pattern-2--move-for-a-duration)
5. [Pattern 3 — The Sine Wave (Hovering)](#5-pattern-3--the-sine-wave-hovering)
6. [Pattern 4 — Circular / Orbit movement](#6-pattern-4--circular--orbit-movement)
7. [Pattern 5 — Sweeping back and forth](#7-pattern-5--sweeping-back-and-forth)
8. [Pattern 6 — Curves (Bézier)](#8-pattern-6--curves-bézier)
9. [Combining movements](#9-combining-movements)
10. [Design tips and feel](#10-design-tips-and-feel)

---

## 1. The one rule of movement

Unlike bullets (which travel in straight lines automatically once spawned), **you must manually update an enemy's position every single frame**.

Because your game uses coroutines, you do this with a `while` loop and `env.wait(0)`.

**The Anatomy of a Movement Loop:**
```lua
local e = env.enemy
while true do
    -- 1. Calculate how much to move this frame
    -- 2. Add it to e.x and e.y
    e.x = e.x + (velocityX * env.dt)
    e.y = e.y + (velocityY * env.dt)
    
    -- 3. Yield to the game engine for 1 frame
    env.wait(0) 
end
```

`env.wait(0)` means "pause this code until the next frame". Without it, the `while` loop would freeze your game forever.
`env.dt` is the "delta time" (the fraction of a second since the last frame), which keeps movement smooth regardless of frame rate.

---

## 2. The math — distance and direction

To move an enemy from Point A to Point B, you need to find the **direction vector**.

### Finding the distance
First, find the horizontal (`dx`) and vertical (`dy`) differences:
```lua
local dx = targetX - e.x
local dy = targetY - e.y
```

Then, use the Pythagorean theorem to find the total straight-line distance:
```lua
local dist = math.sqrt(dx * dx + dy * dy)
```

### Normalizing (The magic step)
Right now, `dx` and `dy` might be massive numbers (like 300 pixels). If you added them directly to `e.x`, the enemy would teleport.

You must **normalize** the vector, meaning you shrink it down to a length of exactly `1.0`. You do this by dividing `dx` and `dy` by the `dist`.

```lua
local dirX = dx / dist
local dirY = dy / dist
```

Now `dirX` and `dirY` describe pure *direction*. 
To move the enemy, multiply the direction by your `speed` and `dt`:

```lua
e.x = e.x + (dirX * speed * env.dt)
e.y = e.y + (dirY * speed * env.dt)
```

---

## 3. Pattern 1 — Simple move to point

Let's put the math together. This moves an enemy to a specific `tx, ty` coordinate and stops when it arrives.

```lua
function movement.to(env, props)
    local e = env.enemy
    local speed = props.speed or 100
    
    while true do
        local dx = props.tx - e.x
        local dy = props.ty - e.y
        local dist = math.sqrt(dx * dx + dy * dy)
        
        -- If we are very close, snap to the target and stop moving
        if dist <= 1 then 
            e.x = props.tx
            e.y = props.ty
            break -- exits the while loop
        end
        
        -- Move toward the target
        e.x = e.x + (dx / dist) * speed * env.dt
        e.y = e.y + (dy / dist) * speed * env.dt
        
        env.wait(0)
    end
end
```

**Usage in a stage:**
```lua
moveScript = function(env)
    -- Enter the screen
    movement.to(env, {tx = 320, ty = 120, speed = 80})
    -- Wait 3 seconds
    env.wait(3)
    -- Leave the screen
    movement.to(env, {tx = 320, ty = -100, speed = 120})
end
```

---

## 4. Pattern 2 — Move for a duration

Sometimes you don't care about reaching a specific destination. You just want the enemy to fly straight down for 2 seconds.

```lua
function movement.flyDirection(env, props)
    local e = env.enemy
    local speed = props.speed or 100
    local angle = props.angle or (math.pi / 2) -- default down
    local duration = props.duration or 2
    
    local elapsed = 0
    
    while elapsed < duration do
        -- Track how much time has passed
        elapsed = elapsed + env.dt
        
        -- Standard angle math (from the bullet guide)
        e.x = e.x + math.cos(angle) * speed * env.dt
        e.y = e.y + math.sin(angle) * speed * env.dt
        
        env.wait(0)
    end
end
```

**Usage:**
```lua
moveScript = function(env)
    -- Fly diagonal-down for 3 seconds
    movement.flyDirection(env, {angle = math.pi/4, speed = 150, duration = 3})
end
```

---

## 5. Pattern 3 — The Sine Wave (Hovering)

If an enemy just sits perfectly still at `x=320, y=120`, it feels rigid and robotic. We can make it "breathe" or hover using `math.sin`.

`math.sin(time)` creates a smooth, repeating wave that oscillates between `-1` and `1`. 

```lua
function movement.hover(env, props)
    local e = env.enemy
    local anchorX = e.x -- Remember where we started
    local anchorY = e.y
    
    local time = 0
    local amplitude = props.amplitude or 10 -- How far it wobbles (pixels)
    local speed = props.speed or 2 -- How fast it wobbles
    
    while true do
        time = time + env.dt
        
        -- math.sin(time * speed) produces a wave between -1 and 1
        -- Multiply by amplitude to make it -10 to 10
        local wobble = math.sin(time * speed) * amplitude
        
        -- Add the wobble to the anchor point
        e.y = anchorY + wobble
        
        env.wait(0)
    end
end
```

**What this looks like:**
The enemy floats up and down gently around its starting point forever. Perfect for bosses waiting for the player to attack.

---

## 6. Pattern 4 — Circular / Orbit movement

By using both `math.cos` (for X) and `math.sin` (for Y) driven by time, an enemy will fly in a perfect circle around a center point.

```lua
function movement.circle(env, props)
    local e = env.enemy
    local centerX = props.cx
    local centerY = props.cy
    local radius = props.radius or 50
    local speed = props.speed or 1 -- radians per second
    
    local angle = 0
    
    while true do
        angle = angle + (speed * env.dt)
        
        -- Parametric equation for a circle
        e.x = centerX + math.cos(angle) * radius
        e.y = centerY + math.sin(angle) * radius
        
        env.wait(0)
    end
end
```

---

## 7. Pattern 5 — Sweeping back and forth

A classic shmup movement: the enemy enters, stops, sweeps left and right while shooting, then leaves.

We can achieve this by combining `math.sin` with horizontal movement.

```lua
function movement.sweep(env, props)
    local e = env.enemy
    local anchorX = e.x
    
    local time = 0
    local width = props.width or 100 -- Sweeps 100px left and 100px right
    local speed = props.speed or 1
    local duration = props.duration or 5
    
    local elapsed = 0
    while elapsed < duration do
        elapsed = elapsed + env.dt
        time = time + env.dt
        
        e.x = anchorX + math.sin(time * speed) * width
        
        env.wait(0)
    end
end
```

---

## 8. Pattern 6 — Curves (Bézier)

Sometimes you want an enemy to swoop in gracefully rather than flying in a straight robotic line. 

To do this, we use a **Bézier curve**. A Bézier curve is a path defined by three things:
1. Where it **starts** (the enemy's current `e.x, e.y`)
2. Where it **ends** (`tx, ty`)
3. A **control point** (`ctrlX, ctrlY`) which acts like a giant magnet pulling the curve toward it. 

If the enemy starts at the top, ends at the bottom, but the control point is way off to the right, the enemy will fly in a giant "C" shape.

In Love2D, `love.math.newBezierCurve` handles the heavy math. You just tell it how far along the curve you are using a number `t` (which goes from `0.0` at the start to `1.0` at the end).

```lua
-- Move along a bezier curve over `duration` seconds.
function movement.curve(env, props)
    local e = env.enemy
    
    -- Create the curve object (Start X/Y, Control X/Y, End X/Y)
    local curve = love.math.newBezierCurve(e.x, e.y, props.ctrlX, props.ctrlY, props.tx, props.ty)
    
    local elapsed = 0
    local duration = props.duration or 3
    
    while elapsed < duration do
        elapsed = elapsed + env.dt
        
        -- t is the percentage of completion. 0.0 means 0%, 1.0 means 100%
        local t = math.min(1, elapsed / duration)
        
        -- curve:evaluate(t) gives us the exact X,Y coordinate at that percentage of the curve
        e.x, e.y = curve:evaluate(t)
        
        env.wait(0)
    end
end
```

**Usage:**
```lua
moveScript = function(env)
    -- Assuming enemy starts at x = 0, y = -50
    movement.curve(env, {
        ctrlX = 500, ctrlY = 240, -- The "magnet" pulling it far to the right
        tx = -100, ty = 480,      -- The final destination (bottom left, off screen)
        duration = 4              -- Takes 4 seconds to complete the arc
    })
end
```

---

## 9. Combining movements

Because your `moveScript` runs step by step, you can chain these patterns together easily to make complex behaviors!

### Example: The Classic Boss Entrance

```lua
moveScript = function(env)
    -- 1. Fly down into the arena from the top
    movement.to(env, {tx = 320, ty = 100, speed = 100})
    
    -- 2. Hover gently in place for 3 seconds while giving a warning
    -- (We have to modify hover slightly to accept a duration, see below)
    
    -- 3. Sweep back and forth for 10 seconds while firing attacks
    movement.sweep(env, {width = 150, speed = 1.5, duration = 10})
    
    -- 4. Flee the arena
    movement.to(env, {tx = 320, ty = -100, speed = 200})
end
```

### Making infinite loops timed

Notice how `movement.hover` from earlier used `while true do`? That means it never stops, so the next movement will never run. 

You can easily adapt any movement to have a duration limit just like `sweep` did:

```lua
function movement.hoverTimed(env, props)
    local e = env.enemy
    local anchorY = e.y
    local time = 0
    
    local elapsed = 0
    local duration = props.duration or 3
    
    while elapsed < duration do
        elapsed = elapsed + env.dt
        time = time + env.dt
        
        e.y = anchorY + math.sin(time * (props.speed or 2)) * (props.amplitude or 10)
        env.wait(0)
    end
end
```

---

## 10. Design tips and feel

### Synchronizing Movement and Attacks

Movement and shooting run in completely separate coroutines (`moveScript` vs `attackScript`). They don't inherently know about each other.

If you want an enemy to shoot **only** when it reaches a destination, you can do this by managing a custom state variable on the enemy:

```lua
-- In moveScript:
moveScript = function(env)
    env.enemy.isReadyToShoot = false
    movement.to(env, {tx = 320, ty = 120, speed = 100})
    
    -- Arrived!
    env.enemy.isReadyToShoot = true
    
    movement.sweep(env, {width = 100, duration = 5})
end

-- In attackScript:
attackScript = function(env)
    while true do
        if env.enemy.isReadyToShoot then
            env.shoot("aim", {bulletType = "objects_r5i1", speed = 200})
        end
        env.wait(0.5)
    end
end
```

### Keep it readable

Add these movement functions into your `src/entities/enemies/behaviors/movement.lua` file. This keeps your actual stage files extremely clean, reading like plain English instructions rather than a mess of math equations!
