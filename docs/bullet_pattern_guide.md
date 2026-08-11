# How to Design Bullet Hell Patterns (Danmaku)

Learning to design complex bullet patterns is actually less about being a math genius and more about **playing and experimenting**. Once you understand the core variables, you can invent any pattern you can imagine.

This guide will teach you how to think like a bullet hell designer using a simple trial-and-error approach right inside your game's code.

---

## 1. Master the "Holy Trinity" of Bullet Math
Every single bullet pattern in existence is just a loop that manipulates one or more of these three things using the loop index or time:

*   **Angle / Velocity (Where it goes):** If you change the angle inside a loop, you get a **Fan** or a **Ring**. If you change the angle based on an enemy timer, you get a **Spiral**.
*   **Spawn Position (Where it starts):** If you change the starting X/Y based on the loop index, you get a **Line**, a **Wall**, or an **Arc**.
*   **Speed (How fast it goes):** If you give bullets different speeds inside a loop, you get a pattern that stretches out over time (like a shotgun blast or a thick wave). 

**The Secret:** The most complex patterns simply manipulate 2 or 3 of these at the same time. (For example, a spiral that also fluctuates its speed creates a pulsating galaxy shape).

---

## 2. Learn the Essential Math (It's easier than it sounds!)

*   **Radians and Pi (`math.pi`):** Think in Radians. A full circle is `math.pi * 2`. A half circle is `math.pi`.
*   **Trigonometry (`math.cos` and `math.sin`):** This is how you convert an Angle and a Distance into X and Y coordinates. You will use this exact formula for almost everything:
    *   `X = center_X + math.cos(angle) * distance`
    *   `Y = center_Y + math.sin(angle) * distance`
*   **Fractions / Interpolation:** Always calculate where you are in your loop as a percentage from `0.0` to `1.0` (e.g., `local fraction = i / (count - 1)`). You can then use that fraction to transition smoothly between two angles, two positions, or two speeds.

---

## 3. The Experimental Sandbox Approach

The absolute best way to learn pattern design is simply **"Trial and Error in Code."** It’s like playing with digital Legos. You just change one number, run the game, see what it looks like, and then try changing another number.

### Your Sandbox Code

Add this `sandbox` pattern to your game. This will be your messy workspace.

```lua
function patterns.sandbox(enemy, target, props)
    local count = 20 -- Spawn 20 bullets at once
    
    local ex = enemy.hitboxX
    local ey = enemy.hitboxY

    for i = 0, count - 1 do
        -- 1. Get our fraction (0.0 to 1.0)
        local fraction = i / (count - 1)
        
        -- ==========================================
        -- PLAY WITH THESE THREE VARIABLES BELOW:
        -- ==========================================
        
        -- Variable A: The Angle
        -- math.pi * 2 is a full circle.
        local angle = fraction * (math.pi * 2) 
        
        -- Variable B: The Speed
        local speed = 150
        
        -- Variable C: The Spawn Distance (Offset)
        local offsetDist = 0 
        
        -- ==========================================
        
        -- Calculate the math (you rarely need to change this part)
        local offsetX = math.cos(angle) * offsetDist
        local offsetY = math.sin(angle) * offsetDist
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed

        -- Spawn it!
        bullet.spawn(props.bulletType, ex + offsetX, ey + offsetY, vx, vy, props.behavior)
    end
end
```

### The "What happens if..." Game

Trigger this `sandbox` pattern in your game, and start running experiments. Change one line, run the game, and watch the result.

**Experiment 1: What if speed isn't a flat number, but is based on the fraction?**
*   Change the speed line to: `local speed = 50 + (fraction * 200)`
*   *Result:* You'll see the ring distort into a spiral shape as some bullets fly faster than others!

**Experiment 2: What if we use a sine wave on the speed?**
*   Change the speed line to: `local speed = 150 + math.sin(angle * 4) * 100`
*   *Result:* You'll see the ring turn into a 4-petaled flower shape as it expands! (The `* 4` creates 4 petals).

**Experiment 3: What if we offset the spawn positions?**
*   Change the speed back to `150`, and change the offset line to: `local offsetDist = fraction * 100`
*   *Result:* Instead of spawning from a single point, they spawn in a spiral line stretching away from the boss, and then fly outward.

---

## 4. The Core Loop of Learning

Whenever you play a bullet hell game and see a cool pattern, ask yourself:
1. *Where are the bullets spawning?* (Are they coming from the center, or a line, or a circle?)
2. *What direction are they going?*
3. *Are they all going the same speed?*

If you keep tweaking `angle`, `speed`, and `offsetDist` using `fraction` and `math.sin()`, you will accidentally discover incredible patterns!
