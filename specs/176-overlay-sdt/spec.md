# 176 — The state bytes of the game's own overlays

## What & why

The server sends state bytes with an overlay as it does with an object's resource, and the
resource's own code decodes them. The cave-in warning dust (`gfx/fx/cavewarn`) is the case players
ask for: its first byte is the strength other clients turn into a minesweeper count per tile. An
addon reads an object's bytes through `gob:sdt()` and hears them change through `GobSdtChanged`;
an overlay's bytes have neither, so `gob:overlay()` names the dust and cannot say how strong it is.

This feature gives a native overlay the same pair:

- **`overlay:sdt()`** → `number[][] | nil`, Unprotected. One 1-based array of `0..255` numbers per
  game overlay the entry stands for, in the order they arrived, so `#overlay:sdt() == overlay:count()`.
  A member the server sent no bytes for is the empty array. `nil` for an overlay of yours, for a thing
  you stood at the gob, and once the overlay or its gob is gone. The client never decodes the bytes.
- **`overlay:info().sdt`** on a native overlay: the same value, in the snapshot.
- **`GobOverlaySdtChanged`**, a world bus event, payload `:gob()` `:key()` `:sdt()`: the value
  `overlay:sdt()` answers for a native key changed while that key is on the gob — a second overlay
  of one resource arriving, one of two leaving, a member's bytes rewritten — and for the first value
  a key is given. Once per object however many characters see it; `event:sdt()` is that firing's
  own value. Without it, a second dust burst on a gob that already carries one is invisible to every
  event: `GobOverlayAdded` follows the key, and the key was already there.

The name is the property's: `sdt` is the word `gob:sdt()`, `gob:info().sdt` and `GobSdtChanged`
already use. The array of arrays is the shape a union has, the way `overlay:count()` is a number
where yours answer `1`.

## Acceptance criteria

Each is checked by the task suite named in `tasks.md`.

1. On a native overlay in view, `overlay:sdt()` is an array whose length equals `overlay:count()`,
   and every entry is an array of whole numbers in `0..255`.
2. `overlay:info().sdt` on that overlay has the same contents as `overlay:sdt()`. Neither is the
   other's table, nor the table of a second read.
3. `overlay:sdt()` answers `nil` on an overlay of your own and on a thing you stood at the gob, and
   their `:info()` carries no `sdt`.
4. After `gob:overlay():remove(key)`, the handle you held answers `nil` to `:sdt()`.
5. `overlay:sdt(1)` raises, naming `sdt` and saying the verb takes no argument.
6. `hafen.event():on("GobOverlaySdtChanged", fn)` subscribes. A near miss (`"GobOverlaySdt"`,
   `"OverlaySdtChanged"`) is refused naming both `GobSdtChanged` and `GobOverlaySdtChanged`.
7. Every `GobOverlaySdtChanged` the run sees carries a native key, a live gob, and an `event:sdt()`
   of the same shape as criterion 1.
8. In a mine, a dust burst shows its strength byte through `overlay:sdt()` and fires
   `GobOverlaySdtChanged` (`[manual]`, the server's to cause).

## Out of scope

- **Decoding.** No `strength`, no tile count, no per-resource meaning: the bytes are the
  resource's, and the server can change them in any version.
- **A stable key per member.** Native overlays stay keyed by resource name; the server's overlay id
  is not exposed. `overlay:sdt()` is ordered by arrival, never addressed.
- **`gob:info().overlays`** keeps answering the uncollapsed list of resource names; it gains no bytes.
  `gob:overlay():info()` per entry is the snapshot with them.
- **An addon's own overlay's bytes.** Yours are drawn from your own setters and carry none.

## Docs impact

Written:

- `docs/addons/api/overlay.md`: the `overlay:sdt()` row, the union rule, the `:info()` shapes rule,
  and the *Not here* row that today sends state to `gob:sdt()` as though overlays had none.
- `docs/addons/api/event/bus/world.md`: the `GobOverlaySdtChanged` row and its section beside
  *The state changing*; the *Counted by key* rule that points at the new event.
- `docs/addons/api/event/bus/README.md`: the world family's row of keys.
- `docs/addons/api/gob.md` *State*: a pointer from `gob:sdt()` to the overlay's bytes.
- `docs/client/world-effects.md`: the overlay table gains what this feature reads in `OCache.$overlay`.

Derived impact set:

```bash
grep -rln "state bytes\|sdt" docs/ | sort
grep -rln "GobOverlayAdded\|overlay:count\|is a union" docs/ | sort
```

```text
docs/addons/api/event/bus/world.md     written
docs/addons/api/gob.md                 written (State)
docs/addons/api/overlay.md             written
docs/addons/api/placing.md             unchanged: "no state bytes … or game overlays" stays true of a placing
docs/addons/api/types/world.md         unchanged: GobInfo carries no overlay bytes
docs/addons/api/event/bus/README.md    written
docs/client/README.md                  unchanged unless world-effects.md's row needs a word
docs/client/gob-sprites.md             unchanged: Composite's CUpd, not the overlay path
docs/client/resources.md               unchanged: the OD_RES path
docs/client/world-effects.md           written
```

## Context files

- `docs/addons/api/overlay.md` — 1
- `docs/addons/api/event/bus/world.md` — 2
- `docs/addons/api/event/bus/README.md` — 2
- `docs/addons/api/gob.md` — 1
- `docs/client/world-effects.md` — 1, 2
- `docs/client/state.md` — 1, 2
- `src/io/brodgar/addon/LuaOverlay.java` — 1
- `src/io/brodgar/addon/LuaGobOverlay.java` — 1, 2
- `src/io/brodgar/addon/AddonManager.java` — 1, 2 (`sdtTable`, `nativeOverlayEvent`, the overlay and sdt queues, drains and gates, `BUS_KEYS`, `busKeyRefusal`, `gobLeft`)
- `src/io/brodgar/addon/LuaEvent.java` — 2
- `src/haven/OCache.java` — 1, 2 (`OlSprite`, `$overlay`)
- `src/haven/Gob.java` — 2 (`addol`, `Overlay.remove`, `ctick`'s expiry)
