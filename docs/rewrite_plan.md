# Project L-STG — Rewrite Plan
**Stack:** C++ · raylib · EnTT · sol2 + LuaJIT

---

## Overview

This is a from-scratch rewrite of Project L-STG. The goal is to keep the Lua coroutine scripting system for stage design while moving all engine-level work into C++ using modern tools. You've never used C++, raylib, EnTT, or sol2 before — so this plan is ordered to teach you each layer as you build.

> [!IMPORTANT]
> Learn each tool in isolation before combining them. Do not try to build the full game until you've validated each layer works.

---

## Phase 0 — Prerequisites: Learn C++ Basics

Before touching any of the tools, get comfortable enough with C++ to read and write basic programs. You don't need to be an expert, but you need to understand these concepts:

- Variables, functions, structs, pointers, references
- Header files (`.hpp`) vs source files (`.cpp`)
- How `#include` works and why it matters
- The concept of namespaces (`std::`, `entt::`, etc.)
- Basic memory concepts: stack vs heap, `new`/`delete` (and why you mostly avoid them with modern C++)
- Lambda functions — you'll use these heavily with EnTT

**Recommended resource:** *learncpp.com* — go through it until you're comfortable with chapters 1–9 and chapter 12 (lambdas). You don't need templates deeply yet.

**Time estimate:** 1–2 weeks of reading + small exercises.

---

## Phase 1 — Toolchain Setup

This is pure setup. Nothing game-related yet.

### 1.1 Compiler
Install a modern C++ compiler that supports C++17:
- **Linux:** GCC 11+ via your package manager (`g++`)
- Make sure it's accessible from the terminal: `g++ --version`

### 1.2 Build System: CMake
CMake is the standard build system for C++ projects. It generates the actual build files for your compiler.
- Install via package manager
- Learn the basics: what `CMakeLists.txt` is, how to run `cmake` + `make`/`ninja`
- **Resource:** *CGold CMake guide* or the official CMake tutorial (first two steps only)

### 1.3 Package Manager: vcpkg
vcpkg handles installing your dependencies (raylib, EnTT, sol2, LuaJIT) so you don't have to build them from source manually.
- Clone vcpkg from GitHub and run its bootstrap script
- Integrate it with CMake using the toolchain file
- Install your four dependencies through it:
  - `raylib`
  - `entt`
  - `sol2`
  - `luajit`

> [!NOTE]
> sol2 and LuaJIT need to be configured together. sol2 is a header-only binding — it wraps whatever Lua implementation you point it at. You'll need to tell CMake to link LuaJIT instead of standard Lua.

### 1.4 Editor
- **VS Code** with the C/C++ extension and CMake Tools extension
- Or **CLion** (JetBrains, free for students) which has built-in CMake support

### 1.5 Validation Goal
By the end of Phase 1 you should be able to:
- Write a `main.cpp` that prints "Hello World"
- Build it with CMake successfully
- Run the resulting binary

---

## Phase 2 — Learn raylib in Isolation

Before touching EnTT or Lua, build a tiny toy project with just raylib. This teaches you the rendering and input model you'll use for the whole game.

### What to Learn
- **Window creation and the game loop** — `InitWindow`, `WindowShouldClose`, `BeginDrawing`/`EndDrawing`
- **Drawing primitives** — rectangles, circles (for debugging hitboxes later)
- **Loading and drawing textures** — this is how your sprites will work
- **Input** — `IsKeyDown`, `IsKeyPressed`
- **Audio** — `InitAudioDevice`, `LoadSound`, `PlaySound`, `LoadMusicStream`
- **The canvas/render texture** — `LoadRenderTexture`, `BeginTextureMode` — your game uses a fixed virtual resolution (640×480), so you'll need this to scale up like your current code does

### Validation Goal
Build a small toy: a textured square that moves around the screen with arrow keys, plays a sound when you press space, and renders into a fixed-resolution canvas that scales with the window.

This is essentially a minimal version of your player system. Once this works, you understand raylib enough.

> [!TIP]
> raylib's own `examples/` folder (available on GitHub) is the best learning resource. Run the examples and read their source.

---

## Phase 3 — Learn EnTT in Isolation

Now set aside raylib for a moment and learn EnTT on its own with just text output.

### What to Learn

**The Registry**
The `entt::registry` is the world. Everything lives here. Learn how to:
- Create an entity: `registry.create()`
- Add components: `registry.emplace<Component>(entity, ...args)`
- Remove components: `registry.erase<Component>(entity)`
- Destroy an entity: `registry.destroy(entity)`
- Check if an entity has a component: `registry.all_of<Component>(entity)`

**Views — how systems work**
A view lets you iterate all entities that have a certain set of components:
```
registry.view<Position, Velocity>()
```
This is how your systems operate. Each system is just a function that takes the registry and iterates a view.

**Component design rules**
- Components are plain data structs — no logic, no methods (ideally)
- Systems are free functions or lambdas — they hold the logic
- Tags are empty structs used to mark entities (e.g. `struct PlayerTag {};`)

### Components to Design for Your Game
Think through what data each entity type needs. Sketch these out as structs:
- `Position`, `Velocity` — all moving things
- `Hitbox` — all collidable things (just a radius for circle collision)
- `Sprite` — texture reference + source rect
- `Lifetime` — bullets that auto-despawn after N frames
- `Player` — lives, bombs, power level, invincibility frames
- `Enemy` — hp, type identifier
- `Bullet` — damage value, which team fired it (player vs enemy)
- `BulletPattern` — data driving pattern systems
- `Graze` — for the graze mechanic if you want it

### Systems to Design
Each system is a function called once per frame:
- **MovementSystem** — applies velocity to position
- **BoundarySystem** — despawns bullets that left the play area
- **LifetimeSystem** — ticks down and despawns expired entities
- **CollisionSystem** — player hitbox vs enemy bullets, player shots vs enemies
- **RenderSystem** — draws all entities with Sprite + Position using raylib
- **EnemyAISystem** — runs per-enemy behavior (movement patterns)
- **PlayerSystem** — reads input, moves player, fires shots

### Validation Goal
Create a registry, make 1000 entities each with Position and Velocity, run a movement system, and print positions. Confirm it works. This is enough to trust EnTT.

---

## Phase 4 — Learn sol2 + LuaJIT Embedding in Isolation

This is the most important phase for preserving your scripting system.

### What to Learn

**Creating the Lua state**
sol2 wraps the LuaJIT VM in a `sol::state` object. You create one in C++, and it owns the Lua runtime.

**Running Lua code from C++**
You can run a Lua file or a string directly from C++.

**Exposing C++ functions to Lua**
This is how your stage scripts will call `spawn_enemy`, `spawn_bullet`, etc. You register a C++ lambda under a Lua name, and Lua scripts can call it.

**Reading values back from Lua**
After a script runs or a function is called, you can read Lua values back into C++ variables.

**Coroutine resuming**
This is the key mechanism. In C++:
- Load a Lua file that returns a `coroutine.create(...)` 
- Store the coroutine as a `sol::coroutine` object
- Every frame, call `.resume()` on it
- The coroutine runs until it hits a `coroutine.yield()` (inside your `wait()` function), then pauses
- Next frame, you resume again

Your `wait(n)` function in Lua yields n times — this is pure Lua and needs no changes at all.

### What Lua APIs You Need to Expose
Think through every function your stage scripts call that isn't pure Lua. For your game:
- `spawn_enemy(x, y, type)` → calls into EnTT to create an enemy entity
- `spawn_bullet(x, y, vx, vy, damage)` → creates a bullet entity
- `spawn_boss(x, y, type)`
- `set_bgm(track_name)` → calls raylib audio
- `get_player_pos()` → returns player x, y from the registry
- `wait(frames)` → yields (pure Lua, no C++ needed)

> [!WARNING]
> sol2 works with standard Lua 5.1/5.2/5.3/5.4 and LuaJIT. LuaJIT is API-compatible with Lua 5.1. Make sure sol2 is configured to use LuaJIT headers, not standard Lua headers, in your CMake setup.

### Validation Goal
- Write a C++ program that embeds LuaJIT via sol2
- Expose a `spawn_enemy(x, y)` function that just prints to the terminal
- Write a Lua coroutine script that calls `spawn_enemy` and uses `wait()`
- Resume the coroutine in a loop and confirm it pauses and resumes correctly

Once this works, your scripting pipeline is proven.

---

## Phase 5 — Integration: Connect All Three Layers

Now combine raylib + EnTT + sol2. This is where the real game starts.

### Integration Order

1. **raylib + EnTT** first — get the render system drawing EnTT entities on screen
2. **EnTT + sol2** second — expose spawn functions that create real EnTT entities
3. **raylib + sol2** last — expose audio/input queries to Lua if needed

### The Main Loop Structure
Your C++ game loop will look roughly like:

```
each frame:
  1. raylib: poll input
  2. PlayerSystem: move player based on input
  3. StageRunner: resume Lua coroutine (spawns enemies/bullets via bindings)
  4. EnemyAISystem: update enemy movement/patterns
  5. MovementSystem: apply all velocities
  6. BoundarySystem: despawn out-of-bounds entities  
  7. LifetimeSystem: despawn expired entities
  8. CollisionSystem: resolve hits, apply damage
  9. RenderSystem: draw all entities via raylib
```

### The Stage Runner
This is the C++ component that owns the Lua coroutine:
- Loads the stage script file
- Holds the `sol::coroutine`
- Resumes it once per frame (or per fixed tick)
- When the coroutine finishes (returns), the stage is over — trigger stage-clear logic

---

## Phase 6 — Port Game Content

By now the engine works. This phase is about porting your existing content.

### What Carries Over Directly (no rewrite needed)
- `scripts/stages/` — your stage Lua files, with API calls updated to the new bindings
- `scripts/patterns/` — bullet pattern definitions
- All assets: `sprites/`, `bgm/`, `sfx/`, `fonts/` — raylib can load all of these formats

### What Needs Rewriting
- All `love.*` API calls in Lua → replaced with your new C++ bindings
- `src/entities/` logic → reimplemented as EnTT systems and components
- `src/misc/` (collision, audio, score, etc.) → reimplemented as C++ systems
- Shaders → GLSL shaders still work in raylib via `LoadShader`

### Port Order
1. Player movement and shooting
2. One simple enemy type
3. One bullet pattern
4. Collision + health
5. Score system
6. One full stage script (stage0)
7. GUI / HUD
8. Menu system
9. Remaining stages, enemies, bosses
10. Shaders and VFX

---

## Phase 7 — Polish

- Object pooling for bullets (pre-allocate a fixed pool, reuse entities instead of create/destroy)
- Fixed timestep (you already do this in Love2D — replicate `1/60` fixed update in C++)
- Screen shake, hit-flash, death explosions (VFX system)
- Replay system (optional but classic for STGs)
- Packaging / distribution

---

## Summary Checklist

```
[ ] Phase 0: C++ fundamentals (learncpp.com ch1-9, 12)
[ ] Phase 1: Toolchain — GCC, CMake, vcpkg, 4 dependencies installed
[ ] Phase 2: raylib toy — textured sprite, input, audio, render texture
[ ] Phase 3: EnTT toy — 1000 entities, movement system, text output
[ ] Phase 4: sol2+LuaJIT toy — coroutine resume loop with spawn binding
[ ] Phase 5: Integration — all three layers working together
[ ] Phase 6: Content port — player → enemies → stages → GUI
[ ] Phase 7: Polish — pooling, VFX, fixed timestep, packaging
```

---

## Resources

| Topic | Resource |
|---|---|
| C++ | learncpp.com |
| raylib | raylib.com/examples + cheatsheet |
| EnTT | EnTT docs on GitHub (skypjack/entt) — read the "Crash Course" in the wiki |
| sol2 | sol2.readthedocs.io — read "Getting Started" + "Coroutines" |
| LuaJIT | luajit.org/luajit.html — compat notes with Lua 5.1 |
| CMake + vcpkg | vcpkg.io/en/getting-started + cmake.org/cmake/help/latest/guide/tutorial |
