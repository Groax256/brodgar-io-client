# 177 — Plan

## Approach

**The client's own gobs (177.1).** One predicate in `AddonManager`, applied where the addon layer first
meets the object cache, so every read and every event downstream inherits it:

```java
/** A gob the CLIENT minted to carry a one-shot effect (an {@code OCache.Virtual}: a footstep's sound, an
 *  effect an animation throws off) -- no server object. Its id is a per-cache counter from -1 down, so one
 *  id names a different gob in every session, and Gob.ctick drops it the tick its effect ends. The world
 *  surface is what the server sends, so none of these is in it. The test is the CLASS, never Gob.virtual:
 *  OCache.receive sets that flag on server objects too (delta flag 2), under their real ids. */
static boolean clientGob(Gob g) {
    return g instanceof OCache.Virtual;
}
```

Applied at:

- **`getgob(long id)`** and **`getgob(String user, long id)`** — `Gob g = oc.getgob(id); return
  ((g == null) || clientGob(g)) ? null : g;`. Every `LuaGob` verb, `nativeEdge`/`nativeHeld`, the
  overlay reads and `gob():get(id)` go through these, so a negative-id handle reads `:exists() == false`.
- **`holds(Sessions.Member, long)`** — `Gob g = gl.oc.getgob(id); return (g != null) && !clientGob(g);`.
  `gobHeld`, `gobUser`, `gobUsers` and `gobCopies` read through it.
- **`allGobs(String user)`** — the walk's test becomes `(g != null) && !clientGob(g) && (oc.getgob(g.id)
  == g)`. `list`, `count`, `find`, `nearest`, `within` are built on it.
- **`registerOcache`'s `ChangeCallback`** — `added` and `removed` return first for a client gob, before
  `armHold`: such a gob is never held out of the render tree and never queued as a `GobEvent`, so
  `GobAdded`/`GobRemoved` never see it.
- **`nativeOverlayEvent`** — returns for a client gob right after its `overlaySubs` check, ahead of both
  the overlay capture and the `GobOverlaySdtChanged` capture. **`queueOverlaySdtEvent`**'s own
  `instanceof OCache.Virtual` test becomes `clientGob(g)` (it still guards the `CUpd` seam's path),
  and its comment shortens to point at `clientGob`.

`queueGobOverlay` (an addon's own attach) needs nothing: its gob came from a handle, which `getgob` now
never resolves to a client gob.

**The Overlay reads (177.2).** In `LuaOverlay.methods`, the eight `OneArgFunction`s — `key`, `gob`,
`native`, `res`, `kind`, `count`, `exists`, `info` — become `VarArgFunction`s whose first line is the
`Args.only` that `sdt` already uses. The body is otherwise unchanged; `self` is what `Args.only` hands
back. The shape, for `key`:

```java
m.set("key", new VarArgFunction() {
    public Varargs invoke(Varargs a) {
        return LuaValue.valueOf(handle(Args.only(a, 0, "overlay:key"), "key").key);
    }
});
```

and for a verb with a longer body, `count`:

```java
m.set("count", new VarArgFunction() {
    public Varargs invoke(Varargs a) {
        LuaOverlay h = handle(Args.only(a, 0, "overlay:count"), "count");
        ...   // the existing body, unchanged
    }
});
```

`Args.only(a, 0, verb)` raises `overlay:count: takes no arguments, got 1 — an argument a verb does not
take is refused rather than dropped`. `sdt`'s comment loses "A VarArgFunction so a surplus argument is
refused", which is now true of every read. `__tostring` stays a `OneArgFunction`: it is a metamethod,
not a verb.

## Files to create/modify

| File | Task | Change |
|---|---|---|
| `src/io/brodgar/addon/AddonManager.java` | 1 | `clientGob`; the two `getgob`s, `holds`, `allGobs`, `registerOcache`'s callback, `nativeOverlayEvent`, `queueOverlaySdtEvent` |
| `src/io/brodgar/addon/LuaOverlay.java` | 2 | the eight reads become `VarArgFunction`s with `Args.only(a, 0, …)` |
| `docs/addons/api/world.md` | 1 | *Objects*: the rule row |
| `docs/addons/api/event/bus/world.md` | 1 | *Only objects the game sends* |
| `addons/177-client-gobs-and-overlay-arity.1/`, `.2/` | 1, 2 | the suites |

`docs/client/state.md` already states that `OCache.Virtual` mints per-cache negative ids, that `OCache.add`
puts one in `objs`, and that `instanceof OCache.Virtual`, not `Gob.virtual`, is the test. No map page
changes.

Doc text, 177.1. `world.md`, a row after `:get(id) never answers nil`:

```markdown
| What the server sends | The collection holds the game's objects and nothing the client makes for itself: a footstep's sound or a passing effect is carried by a gob of the client's own, which no verb lists and `:get` never finds. |
```

`event/bus/world.md`, the *Only objects the game sends* row becomes:

```markdown
| Only objects the game sends | A [thing of your own](../../virtual/README.md) (a ghost, a sprite, a model, a standing widget, a patch) fires no `GobAdded`. It is drawn the moment you place it. Neither does a gob the client makes for itself to carry a footstep's sound or a passing effect, and nothing on one fires an overlay event. |
```

## Risks & gotchas

- **`OCache.Virtual` subclasses.** `OCache.FixedPlace extends Virtual`, and `Skeleton` builds an
  anonymous `FixedPlace` subclass; `instanceof` covers all of them.
- **`Gob.virtual` is not the test** (see `clientGob`'s comment, and `docs/client/state.md`). The cave-in
  dust (`gfx/fx/cavewarn`) hangs on a server object flagged virtual; 176's suite saw it pass while the
  flag was wrongly the test.
- **`OCache.objs` is a `MultiMap`.** A client gob and a server gob never share an id (negative vs
  server-issued), so filtering the answer of `getgob(id)` loses nothing.
- **The render hold.** `armHold` in the callback must not run for a client gob: nothing would announce it
  and it would wait for the next drain. Return before it.
- **Other `oc` readers stay as they are**: `LuaVoice.visiblePlayers` filters for players,
  `ResourceWrites` reloads every gob (a client gob draws a resource too), `FollowMoving` and
  `VirtualApi`'s follow targets take ids from handles, `Performance` and `Obstruction` measure what is
  drawn. None is a read an addon receives a gob from.
- **Checkers.** `tools/docverbs.py`, `tools/refusalverbs.py`, each run bare. `rm -rf build/classes`
  before the compile check; `rm build/hafen.jar` if `ant bin` reports a truncated jar.

## Discarded alternatives

- **Testing `Gob.virtual`** — the server sets it on objects of its own under real ids, and the cave-in
  dust is one: the flag would hide what the feature before this one exists to report.
- **Testing `id < 0`** — it states the symptom rather than the cause; the class is what mints the id.
- **Filtering at each event's drain** — four drains and six reads each repeating one test, where two
  lookups, one walk and one callback carry it for all of them.
- **Keying the once-per-object gates by (session, id)** — the gates are right for server objects; a
  client gob is no object to gate.
- **Fixing every verb's arity here** — 327 verbs across the bridge drop a surplus argument; the overlay
  surface closes here and the API-wide sweep needs a census and tasks of its own.
- **Converting `__tostring` too** — a metamethod is called by Lua with the arity
  Lua chooses; it is no verb an addon calls.
