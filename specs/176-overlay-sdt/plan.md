# 176 — Plan

## Approach

**The read (176.1).** One walk, beside the two that already exist, in `LuaGobOverlay`:

```java
/** The state bytes of every game overlay on {@code g} keyed {@code key}, in Gob.ols order: a copy each,
 *  taken under the gob's own monitor (the one OCache.ObjDelta.apply and Gob.defer hold), so a loader
 *  thread rewriting OlSprite.sdt cannot tear one. Filtered by nativeKey exactly as countNative is, so
 *  the list's size IS countNative(g, key). A member with no mill (built from a Sprite) answers {}. */
static List<byte[]> nativeSdt(Gob g, String key) {
    List<byte[]> out = new ArrayList<byte[]>();
    synchronized(g) {
        for(Gob.Overlay ol : g.ols) {
            if(!key.equals(nativeKey(ol)))
                continue;
            byte[] b = null;
            if(ol.sm instanceof OCache.OlSprite)
                b = ((OCache.OlSprite)ol.sm).sdt;
            else if(ol.sm instanceof Sprite.Mill.FromRes)
                b = ((Sprite.Mill.FromRes)ol.sm).sdt;
            out.add((b == null) ? new byte[0] : b.clone());
        }
    }
    return out;
}
```

`AddonManager` gains `static LuaValue sdtList(List<byte[]>)`: a 1-based array of `sdtTable(b)`
(the existing private conversion, a fresh table per call). `LuaOverlay.methods` gains `sdt` as a
`VarArgFunction` (no `OneArgFunction`: `Args.only` explains why):

```java
m.set("sdt", new VarArgFunction() {
    public Varargs invoke(Varargs a) {
        LuaOverlay h = handle(Args.only(a, 0, "overlay:sdt"), "sdt");
        if(h.src != NATIVE)
            return LuaValue.NIL;
        Gob g = AddonManager.getgob(h.user, h.gob);
        if(g == null)
            return LuaValue.NIL;
        List<byte[]> l = LuaGobOverlay.nativeSdt(g, h.key);
        return l.isEmpty() ? LuaValue.NIL : AddonManager.sdtList(l);
    }
});
```

`info()`'s `NATIVE` branch sets `sdt` from the same list (and `count` from its size, so the two
fields cannot disagree inside one snapshot). The other two branches set neither.

**The event (176.2).** `GobOverlaySdtChanged`, payload `:gob()` `:key()` `:sdt()`, broadcast, once
per object. It is the `GobSdtChanged` machinery one level down, keyed on `(gob id, key)`:

- **Arming.** `static volatile boolean overlaySdtSubs`, set in `hafen.event():on` when
  `key.equals("GobOverlaySdtChanged")` (the existing `startsWith("GobOverlay")` arms `overlaySubs`
  too, which `nativeOverlayEvent` needs), cleared beside `sdtSubs` on reload.
- **Capture at three seams, value taken there.** (1) `nativeOverlayEvent`, which `Gob.addol` and both
  removal paths already reach: when `overlaySdtSubs`, queue `new OverlaySdtEvent(g.id, key,
  LuaGobOverlay.nativeSdt(g, key))` **before** the union gate returns, so a second member arriving
  is captured. (2) A new tagged line in `OCache.$overlay`'s `Sprite.CUpd` branch, after
  `os.sdt = sdt;`: `io.brodgar.addon.AddonManager.gobOverlaySdtChanged(g, ol);   // addon: 176.2 ...`
  — the one place a member's bytes are rewritten without an add or a removal. It resolves the key with
  `LuaGobOverlay.nativeKey(ol)` and queues the same event. Neither seam calls Lua or throws.
- **Queue and drain.** `SessionState.overlaySdtEvents`, queued through `queueState(Sessions.uifor(
  g.glob))` like `queueSdtEvent`, cleared beside `overlayEvents` on reload. `drainOverlaySdtEvents(st)`
  runs right after `drainOverlayEvents(st)`, so a key's `GobOverlayAdded` precedes its first change.
- **Gate.** `Map<Long, Map<String, List<byte[]>>> lastOverlaySdt`. An empty list removes the key's
  entry and fires nothing (that moment is `GobOverlayRemoved`). Otherwise fire exactly when the list
  differs element-wise (`Arrays.equals` per member, sizes first) from the one last reported, and
  record it. `gobLeft` drops the gob's entry beside `lastSdt`. Two sessions reporting one change fire
  once, as `sdtEdge` does.
- **Fire.** `fireGobOverlaySdt(gobId, key, list)` loops `addons` then `consoleOwner` like
  `fireGobSdt`, converting with `sdtList` per owner. `LuaEvent` gains a shape `OVERLAYSDT`
  (`"overlay state-change event"`) carrying `gobId`, `key` and the value in `extra`, answering
  `:gob()` `:key()` `:sdt()`. No `:native()`: the event is native only.
- **Key.** `"GobOverlaySdtChanged"` in `BUS_KEYS` after `"GobSdtChanged"`. `busKeyRefusal`'s `sdt`
  hint becomes ` — the keys are GobSdtChanged (an object's state bytes) and GobOverlaySdtChanged
  (the state bytes of the game's overlays on it)`. `"GobOverlaySdt"` and `"OverlaySdtChanged"` both
  reach it.

## Files to create/modify

| File | Task | Change |
|---|---|---|
| `src/io/brodgar/addon/LuaGobOverlay.java` | 1 | `nativeSdt` |
| `src/io/brodgar/addon/LuaOverlay.java` | 1 | `sdt` verb; `sdt` in the native `info()` |
| `src/io/brodgar/addon/AddonManager.java` | 1, 2 | `sdtList` (1); the flag, queue, seam entry, drain, gate, fire, key and hint (2) |
| `src/io/brodgar/addon/LuaEvent.java` | 2 | `OVERLAYSDT` shape, constructor, methods |
| `src/haven/OCache.java` | 2 | one `// addon: 176.2` line in `$overlay` |
| `docs/addons/api/overlay.md` | 1 | the row, a *The game's state bytes* section (example, answers table), the union and `:info()` rules, the *Not here* row |
| `docs/addons/api/gob.md` | 1 | *State*: one sentence pointing at `overlay:sdt()` |
| `docs/addons/api/event/bus/world.md` | 2 | the row, *An overlay's state changing* section, the *Counted by key* rule |
| `docs/addons/api/event/bus/README.md` | 2 | the key in the world row |
| `docs/client/world-effects.md` | 1, 2 | the overlay table: `OlSprite.sdt` is mutable; how `$overlay` handles a change of bytes (1); the seam (2) |
| `addons/176-overlay-sdt.1/`, `addons/176-overlay-sdt.2/` | 1, 2 | the suites |

## Risks & gotchas

- **`OCache.OlSprite.sdt` is not final.** `$overlay` rewrites it in place when the drawn sprite is
  a `Sprite.CUpd`; otherwise it builds a new `Gob.Overlay`, `addol(nol, false)` then
  `ol.remove(false)`. So a rewritten member that is not `CUpd` (`Cavein` is `Sprite.CDel`) passes
  through a moment holding both: the event fires twice, old-and-new then new. That is the truth
  `count()` already tells; the docs say it without naming the engine.
- **`Sprite.CDel` lingers.** A `$overlay` removal calls `delete()` on such a sprite and leaves it in
  `Gob.ols` until `Gob.ctick`'s `ol.tick(dt)` reports it done. An ended dust burst stays in the read
  while it settles. Its removal reaches `nativeOverlayEvent` through the `ctick` seam.
- **The monitor.** `Gob.defer` and `OCache.ObjDelta.apply` hold `synchronized(gob)` while
  `Gob.ols` changes (`docs/client/world-3d.md`, `state.md`); the monitor is reentrant, so
  `nativeSdt` inside a seam is safe. Never build Lua under it.
- **`Loading`.** `nativeKey` already answers `null` while `spr.res` resolves; `Gob.addol` calls
  `ol.init()` before `ols.add`, so the add seam sees a built sprite.
- **`Gob.Overlay(Gob, Sprite)`** has `sm == null`. It is still the game's own, so it is a member, `{}`.
- **The LuaOverlay verbs other than `sdt` are `OneArgFunction`s** and do not refuse a surplus
  argument. That predates this feature; `sdt` refuses. Report it at the close.
- **Checkers.** `tools/docverbs.py` and `tools/refusalverbs.py`, each run bare; grep the new rows
  against `m.set` anyway. `rm -rf build/classes` before the compile check.

## Discarded alternatives

- **`overlay:sdts()`** — the property is `sdt` in `gob:sdt()`, `gob:info().sdt` and `GobSdtChanged`;
  a plural nobody else spells would be a second name for one property.
- **`overlay:sdt()` answering the newest member's `number[]`** — every member but one is lost, and
  publishing the rest later needs a second verb for the same bytes.
- **The bytes in `:info()` only** — every snapshot field has a live read of the same name; one without
  would be the only field an addon cannot poll.
- **Keying native overlays by the server's overlay id** — that id is absent when the server gives none,
  is a number where every other overlay key is a name, and changes when a member is rebuilt.
- **The bytes on `GobOverlayAdded`** — that event follows the key, so the second member of a resource
  fires none, and an addon arriving after the overlay never hears it.
- **One `GobOverlayAdded` per member** — the read is a union keyed by name; an add the read cannot
  tell apart from the one before contradicts it.
- **A live re-read at the drain** — two changes inside one frame would report the last twice and the
  first never, the reason `GobSdtChanged` carries its own bytes.
- **Decoding the cave-in strength in the client** — the bytes are the resource's, and other clients
  disagree even on rounding it.
- **`:native()` on the payload** — always `true`.
