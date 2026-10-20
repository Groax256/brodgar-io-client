# 177 — The client's own gobs leave the world surface; the Overlay reads refuse a surplus argument

## What & why

Two defects in published surfaces, each a place where the client says something its own pages deny.

**The client's own gobs.** The client mints throwaway gobs of its own to carry a one-shot effect: a
footstep's sound (`sfx/tiles/hstep`), an effect an animation throws off. Each carries an id from a
per-session counter that runs from `-1` down, so `-1` names a different gob in each of your characters,
and the gob is dropped the tick its effect ends. They are no server object, yet they reach the world
surface: `GobAdded`/`GobRemoved`, `GobOverlayAdded`/`GobOverlayRemoved`, and every
`session:world():gob()` read (`list`, `count`, `find`, `nearest`, `within`, `get`). An addon logging what
comes into view sees a gob with a negative id per step, and the once-per-object gate, keyed by id,
counts two characters' different `-1`s as one object. The pages already say the world is the game
objects the server sends; this feature makes the client agree. `GobOverlaySdtChanged` (176) already
excludes them; the rule becomes one, at the surface's own lookups, for every read and every event.

The test is the client-minted class, never the `virtual` flag a gob carries: the server sets that flag
on objects of its own too, under their real ids, and the cave-in warning's dust hangs on one of those.

**The Overlay object's reads.** `overlay:key()`, `:gob()`, `:native()`, `:res()`, `:kind()`,
`:count()`, `:exists()` and `:info()` silently drop an argument they do not take, while
`conventions.md` states that a surplus argument raises and `overlay:sdt()` does. `overlay:count(5)`
reads like a write and is answered as a read, with nothing said. Each refuses it, naming the verb and
saying it takes no arguments.

## Acceptance criteria

Each is checked by the task suite named in `tasks.md`.

1. While the character walks, no `GobAdded`, `GobRemoved`, `GobOverlayAdded` or `GobOverlayRemoved`
   the run sees carries a gob whose `:id()` is negative.
2. While the character walks, no `session:world():gob():list()` sampled every frame holds a gob whose
   `:id()` is negative, and `:get(id)` on a negative id answers a gob whose `:exists()` is false.
3. The game's own objects and overlays are still reported: the run sees at least one `GobAdded` and at
   least one native `GobOverlayAdded`, each with a positive id.
4. Each of `overlay:key`, `:gob`, `:native`, `:res`, `:kind`, `:count`, `:exists`, `:info` called with
   one argument raises a message naming `overlay:<verb>` and `no arguments`.
5. Each of the same verbs called bare still answers on a native overlay and on one of yours.
6. Footsteps are heard and the world draws as before while walking (`[manual]`).

## Out of scope

- **The rest of the API's arity.** 327 published verbs across the bridge are built the way the Overlay
  reads are and drop a surplus argument the same way (`LuaSession` 25, `LuaWidget` 17, `LuaGob` 15,
  `LuaItem` 13, …). This feature closes the overlay surface; the API-wide sweep, which needs a census
  of its own and several tasks, is the other half.
- **`gob:overlay()`'s collection verbs** — `list`, `get`, `add`, `remove` are the shared collection's,
  whose arity belongs to that sweep.
- **The effects those gobs carry.** No addon reads a footstep's sound; nothing replaces the leak.
- **The client's own `hafen.virtual()` entities** — never in the object cache, already outside every
  read.

## Docs impact

Written:

- `docs/addons/api/world.md`: the collection's rules say it holds only what the server sends.
- `docs/addons/api/event/bus/world.md`: *Only objects the game sends* names the client's own effect
  carriers beside your things; the overlay events follow it.
- `docs/client/state.md` is unchanged: it already maps `OCache.Virtual`'s per-cache negative ids, its
  place in `objs`, and the class test.

Derived impact set:

```bash
grep -rln "game objects\|GobAdded\|gob():list\|Only objects the game sends" docs/ | sort
grep -rln "surplus argument" docs/ | sort
```

```text
docs/addons/api/world.md                 written (the collection's rules)
docs/addons/api/event/bus/world.md       written (Only objects the game sends)
docs/addons/api/conventions.md           unchanged: "a surplus argument raises" becomes true of overlays
docs/addons/api/fight.md                 unchanged: its own verbs' surplus row
docs/addons/api/overlay.md               unchanged: the reads keep their rows; the convention covers arity
docs/addons/api/gob.md                   unchanged: "the server's object" already
docs/addons/api/types/world.md           unchanged: GobInfo shape untouched
docs/addons/api/event/README.md, event/bus/README.md   unchanged: key sets untouched
docs/addons/api/placing.md, virtual/README.md          unchanged: your things, never these
docs/addons/api/client/profiling/*.md, kin.md, log.md, look.md, references.md, threading.md   unchanged: mention GobAdded or game objects in passing
docs/addons/getting-started.md, guides/*.md            unchanged: examples over real objects
```

## Context files

- `docs/addons/api/world.md` — 1
- `docs/addons/api/event/bus/world.md` — 1
- `docs/addons/api/overlay.md` — 2
- `docs/addons/api/conventions.md` — 2
- `src/io/brodgar/addon/AddonManager.java` — 1 (`registerOcache`, `nativeOverlayEvent`, `queueOverlaySdtEvent`, `getgob`, `holds`, `allGobs`)
- `src/io/brodgar/addon/LuaOverlay.java` — 2 (`methods`)
- `src/io/brodgar/addon/Args.java` — 2 (`only`)
- `src/haven/OCache.java` — 1 (`Virtual`, `add`, `getgob`)
