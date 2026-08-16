# EnTT: Getting Started + API Reference

[EnTT](https://github.com/skypjack/entt) is a header-only C++ entity-component-system (ECS) library. This doc has two parts: **Part 1** teaches you the concepts and gets a minimal program running. **Part 2** is a syntax reference to keep open once you're building.

```cpp
#include <entt/entt.hpp>
```

---

# Part 1 — Getting Started

## 1.1 What ECS actually is

In normal OOP, an object bundles data *and* behavior: a `Player` class has HP, position, and an `update()` method. ECS splits that apart into three things:

- **Entity** — just an ID number. No data, no behavior. Think of it as a row key in a database.
- **Component** — pure data, no methods. `struct Position { float x, y; };`
- **System** — a plain function that operates on entities which have a given set of components. `void movement_system(...)`

So instead of "a Player object that has a position and knows how to move," you have: an entity, tagged with a `Position` component and a `Velocity` component, and a `movement_system` function that runs over every entity that has both.

**Why bother?** Two big reasons:
1. **Composition over inheritance.** Want a flying enemy that's also poisonous? Just attach a `Flying` component and a `Poison` component to it. No diamond-inheritance mess.
2. **Performance.** Components of the same type are stored contiguously in memory, so systems that loop over "every entity with a `Position`" iterate over tightly-packed arrays instead of chasing pointers around scattered objects.

The mental shift: **stop thinking "what class is this object?"** and start thinking **"what data does this entity currently have, and what functions care about that combination?"**

## 1.2 The three things you'll touch constantly

- `entt::registry` — owns everything: entities and their components.
- `registry.emplace<T>(entity, ...)` — attach a component to an entity.
- `registry.view<T, U, ...>()` — get an iterable list of entities that have *all* of `T, U, ...`, so a system can loop over exactly the entities it cares about.

That's genuinely most of what you need for a first project.

## 1.3 A complete minimal example

This creates entities, gives them components, and runs one system in a loop — the whole ECS lifecycle in one file.

```cpp
#include <entt/entt.hpp>
#include <iostream>

struct Position { float x, y; };
struct Velocity { float dx, dy; };

// A system is just a function that takes the registry and does its thing.
void movement_system(entt::registry& registry, float dt) {
    auto view = registry.view<Position, Velocity>();

    for (auto entity : view) {
        auto& pos = view.get<Position>(entity);
        auto& vel = view.get<Velocity>(entity);

        pos.x += vel.dx * dt;
        pos.y += vel.dy * dt;
    }
}

int main() {
    entt::registry registry;

    // Spawn a few entities with different component combos.
    for (int i = 0; i < 5; ++i) {
        auto entity = registry.create();
        registry.emplace<Position>(entity, 0.f, 0.f);
        registry.emplace<Velocity>(entity, 1.f, 0.5f);
    }

    // One entity with no Velocity — movement_system will skip it entirely,
    // because the view only returns entities with BOTH components.
    auto stationary = registry.create();
    registry.emplace<Position>(stationary, 10.f, 10.f);

    // A tiny game loop.
    for (int frame = 0; frame < 3; ++frame) {
        movement_system(registry, 1.0f);
    }

    registry.view<Position>().each([](auto entity, auto& pos) {
        std::cout << "Entity " << entt::to_integral(entity)
                   << " at (" << pos.x << ", " << pos.y << ")\n";
    });
}
```

Walk through what happened:
1. `registry.create()` makes an entity — just an ID, nothing attached yet.
2. `registry.emplace<Position>(entity, ...)` attaches data to that ID.
3. `registry.view<Position, Velocity>()` filters down to only entities with both — the `stationary` entity is automatically excluded, no `if` checks needed.
4. The system function doesn't know or care what a "Player" or "Enemy" is — it just moves anything with `Position` + `Velocity`.

## 1.4 Immediate next steps once this makes sense

1. Add a **tag component** (an empty struct like `struct Player {};`) and use `registry.view<Position, Player>()` to single out just the player entity.
2. Add a system that **removes** entities — e.g. a `Health` component, a `damage_system`, and destroying entities whose `hp <= 0` (see the "destroying safely" gotcha in Part 2 §14).
3. Once you have 3+ systems, structure your main loop as a simple ordered list of system calls — that ordering *is* your game's update pipeline.
4. Don't reach for groups, signals, snapshots, or the dispatcher yet — see Part 2, they're for once you have a working game and specific problems to solve (performance, decoupled events, save/load).

## 1.5 Common first-timer mistakes

- **Putting logic inside components.** A component should be plain data — no member functions beyond maybe a constructor. Logic belongs in systems.
- **Storing raw entity references across frames without checking validity.** An entity can be destroyed elsewhere; check `registry.valid(e)` before using a stashed entity ID, or better, use signals to clean up references when an entity dies.
- **Treating an entity like an object handle with identity/behavior.** It's *just an ID*. All the "identity" is really just "what components does this ID currently have."
- **Over-designing components too early.** Start with dumb, obvious data (`Position { x, y }`) rather than trying to design a perfect component taxonomy up front. Refactor components as real needs emerge.

---

# Part 2 — API Reference

## 2.1 Registry — the core container

```cpp
entt::registry registry;
```

| Operation | Call |
|---|---|
| Create entity | `auto e = registry.create();` |
| Destroy entity | `registry.destroy(e);` |
| Check validity | `registry.valid(e)` |
| Number of alive entities | `registry.storage<entt::entity>()->size()` (or `registry.alive()` in older versions) |
| Clear everything | `registry.clear();` |

## 2.2 Components

Any movable/copyable type can be a component — no base class or macro required.

```cpp
struct Position { float x, y; };
struct Velocity { float dx, dy; };
struct Health    { int hp; };
```

| Operation | Call |
|---|---|
| Add / replace | `registry.emplace<Position>(e, 0.f, 0.f);` |
| Add or overwrite | `registry.emplace_or_replace<Position>(e, 1.f, 2.f);` |
| Get (mutable) | `auto& pos = registry.get<Position>(e);` |
| Get (multiple) | `auto [pos, vel] = registry.get<Position, Velocity>(e);` |
| Get or default-construct | `registry.get_or_emplace<Position>(e);` |
| Try-get (nullable) | `auto* pos = registry.try_get<Position>(e);` |
| Has component? | `registry.all_of<Position>(e)` |
| Has any of? | `registry.any_of<Position, Velocity>(e)` |
| Remove | `registry.remove<Position>(e);` |
| Patch in place | `registry.patch<Position>(e, [](auto& p){ p.x += 1; });` |
| Replace | `registry.replace<Position>(e, 5.f, 5.f);` |

## 2.3 Views — iterate entities with a fixed component set

Views are cheap to construct; create them per-frame, don't cache blindly across structural changes.

```cpp
auto view = registry.view<Position, Velocity>();

for (auto e : view) {
    auto& pos = view.get<Position>(e);
    auto& vel = view.get<Velocity>(e);
    pos.x += vel.dx;
    pos.y += vel.dy;
}
```

Or, the shorthand that unpacks components directly:

```cpp
registry.view<Position, Velocity>().each([](auto& pos, auto& vel) {
    pos.x += vel.dx;
    pos.y += vel.dy;
});

// entity + components
registry.view<Position, Velocity>().each([](auto e, auto& pos, auto& vel) {
    // ...
});
```

**Excluding** components:

```cpp
auto view = registry.view<Position>(entt::exclude<Frozen>);
```

## 2.4 Groups — faster iteration for stable component combos

Groups pre-sort underlying storage for cache-friendly iteration. Use when a specific combo is iterated very frequently and doesn't change type composition often.

```cpp
// full-owning group: fastest, but only one group per component per registry
auto group = registry.group<Position, Velocity>();

// partial-owning
auto group = registry.group<Position>(entt::get<Velocity>);

// non-owning (like a multi-component view)
auto group = registry.group<>(entt::get<Position, Velocity>);

group.each([](auto& pos, auto& vel) { pos.x += vel.dx; });
```

Rule of thumb: reach for **views** first; only use **groups** once profiling shows it matters.

## 2.5 Signals / Observers — react to component changes

```cpp
registry.on_construct<Position>().connect<&on_position_added>();
registry.on_update<Position>().connect<&on_position_changed>();
registry.on_destroy<Position>().connect<&on_position_removed>();

// member function
registry.on_construct<Health>().connect<&GameSystem::on_health_added>(system);

// disconnect
registry.on_construct<Position>().disconnect<&on_position_added>();
```

Callback signature: `void(entt::registry&, entt::entity)`

For batching change tracking, use `entt::observer`:

```cpp
entt::observer observer{registry, entt::collector.update<Position>()};

for (auto e : observer) {
    // entities whose Position changed since last clear
}
observer.clear();
```

## 2.6 Entity handles — bundle registry + entity

```cpp
entt::handle h{registry, entity};
h.emplace<Position>(0.f, 0.f);
h.get<Position>();
h.destroy();
```

Useful for passing "an entity that knows its registry" around without threading `registry` everywhere.

## 2.7 Tags / empty components

Empty structs (no data members) are stored with zero memory overhead — ideal for flags.

```cpp
struct Player {};   // tag
struct Frozen {};   // tag

registry.emplace<Player>(e);
if (registry.all_of<Player>(e)) { /* ... */ }
```

## 2.8 Contexts — global / singleton-like data on the registry

```cpp
registry.ctx().emplace<GameState>(GameState::Playing);
auto& state = registry.ctx().get<GameState>();

if (auto* s = registry.ctx().find<GameState>()) { /* ... */ }
```

Good for things like delta time, current level, RNG seed — data that isn't per-entity.

## 2.9 Sorting

```cpp
// sort a single-component storage directly
registry.sort<Position>([](const Position& a, const Position& b) {
    return a.y < b.y;   // e.g. for painter's-algorithm draw order
});

// sort one component's storage to match another's order (for grouped iteration)
registry.sort<Velocity, Position>();
```

## 2.10 Entity relationships / hierarchies

EnTT has no built-in scene graph — model parent/child as components:

```cpp
struct Parent { entt::entity value; };
struct Children { std::vector<entt::entity> value; };
```

## 2.11 Snapshots — serialization

```cpp
entt::snapshot{registry}
    .get<entt::entity>(archive)
    .get<Position>(archive)
    .get<Velocity>(archive);

entt::snapshot_loader{registry}
    .get<entt::entity>(archive)
    .get<Position>(archive)
    .orphans();
```

Archive is any type exposing `operator()` for reading/writing — you write the serialization glue.

## 2.12 Dispatcher & event bus (decoupled events, separate from components)

```cpp
entt::dispatcher dispatcher;

struct CollisionEvent { entt::entity a, b; };

dispatcher.sink<CollisionEvent>().connect<&on_collision>();
dispatcher.trigger<CollisionEvent>(e1, e2);      // immediate
dispatcher.enqueue<CollisionEvent>(e1, e2);      // queued
dispatcher.update<CollisionEvent>();             // flush queue
dispatcher.update();                             // flush all queued event types
```

## 2.13 Resource cache (`entt::resource_cache`)

```cpp
entt::resource_cache<Texture> cache;
cache.load<TextureLoader>(id, "player.png");
auto texture = cache[id];
```

Handles reference-counted shared assets (textures, meshes, sounds).

## 2.14 Common patterns

**System function signature convention:**
```cpp
void movement_system(entt::registry& registry, float dt) {
    registry.view<Position, const Velocity>().each([dt](auto& pos, const auto& vel) {
        pos.x += vel.dx * dt;
        pos.y += vel.dy * dt;
    });
}
```

**Destroying entities safely during iteration** — don't destroy mid-`each`; collect then destroy:
```cpp
std::vector<entt::entity> dead;
registry.view<Health>().each([&](auto e, auto& hp) {
    if (hp.hp <= 0) dead.push_back(e);
});
registry.destroy(dead.begin(), dead.end());
```

**Singleton entity pattern** (when you want "one entity" semantics instead of `ctx()`):
```cpp
auto singleton = registry.view<GameConfig>().front();
```

## 2.15 Gotchas

- Component references (`get<T>()`) can be invalidated by any operation that reallocates that component's storage (e.g. `emplace` on the same type) — don't hold a reference across such calls.
- `view.get<T>(e)` assumes `e` is in the view; use `try_get` if uncertain.
- Full-owning groups are exclusive: a component type can only be "owned" by one group at a time.
- Views/groups don't guarantee iteration order matches creation order.
