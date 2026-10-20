# 176 — Tasks

- [x] **176.1 — A native overlay answers its state bytes.**
      - **Code.** `LuaGobOverlay.nativeSdt(Gob, String)`, `AddonManager.sdtList(List<byte[]>)`, the
        `sdt` verb on the Overlay object and `sdt` in the native branch of `overlay:info()`, exactly as
        `plan.md` *The read* writes them. `sdt` refuses a surplus argument through
        `Args.only(a, 0, "overlay:sdt")`.
      - **Docs.** `overlay.md`: the `overlay:sdt()` row (`number[][] \| nil`, Unprotected); a
        *The game's state bytes* section with a ≤ 12-line example and an answers table (one array per
        member in arrival order, `{}` for none, `nil` for yours, for a thing stood there, once gone; the
        client never decodes them; an overlay the server has ended can stay listed while its effect
        plays out); the union rule and the `:info()` shapes rule naming `sdt`; the *Not here* row
        rewritten so it no longer reads as though overlays carry no state. `gob.md` *State*: one
        sentence pointing at `overlay:sdt()`. `docs/client/world-effects.md`: `OlSprite.sdt` is mutable,
        and what `$overlay` does with changed bytes (`CUpd` in place, else add then remove). Covers
        criteria 1–5.
      *Its suite* (`:t176`) waits on a Done button while the maintainer stands where the game draws
      overlays (a lit fire, a mine). Then it walks every native overlay on every gob in view and
      asserts, per overlay, that `#ol:sdt() == ol:count()` and every entry is whole and in `0..255`. It
      fails naming "no native overlay in view" when it finds none. On the first one it asserts that
      `ol:info().sdt` matches `ol:sdt()` member by member, and that `ol:sdt() ~= ol:sdt()` and
      `ol:info().sdt ~= ol:sdt()`. It attaches `"t176"` (a text) to the player's gob and asserts
      `:sdt()` is `nil` and `:info().sdt` absent. It does the same for a ghost anchored to that gob,
      read back through `gob:overlay():list()`, then removes both. It asserts the held `"t176"` handle
      answers `nil` after `:remove`. `pcall(ol.sdt, ol, 1)` must fail with a message containing
      `overlay:sdt` and `no arguments`.
      `[manual]`: none.

- [ ] **176.2 — GobOverlaySdtChanged.**
      - **Code.** The event as `plan.md` *The event* writes it: `overlaySdtSubs`;
        `SessionState.overlaySdtEvents` and `OverlaySdtEvent`; the capture in `nativeOverlayEvent`
        ahead of the union gate; `gobOverlaySdtChanged(Gob, Gob.Overlay)` and its one tagged line in
        `OCache.$overlay`'s `Sprite.CUpd` branch; `drainOverlaySdtEvents` after `drainOverlayEvents`;
        `lastOverlaySdt`, dropped in `gobLeft`; `fireGobOverlaySdt`; `LuaEvent`'s `OVERLAYSDT`
        shape; the key in `BUS_KEYS` and the reworded `sdt` hint in `busKeyRefusal`. Clear the queue
        and the flag on reload, beside their neighbours.
      - **Docs.** `event/bus/world.md`: the row in *World*; an *An overlay's state changing* section
        after *The state changing*, in its shape (the payload table, an example, rules: once per object,
        next frame and after `GobOverlayAdded`, fires for the first value, not on the last removal,
        `event:sdt()` is that firing's own, a rewritten member can arrive before the old one leaves so
        the event fires for both moments, never owner-scoped); *Counted by key* points at the new key.
        `event/bus/README.md`: the key in the world row. `docs/client/world-effects.md`: the seam.
        Covers criteria 6–8.
      *Its suite* (`:t176`) first asserts `hafen.event():on("GobOverlaySdt", fn)` and
      `("OverlaySdtChanged", fn)` both fail with a message naming `GobSdtChanged` and
      `GobOverlaySdtChanged`. It subscribes `GobOverlaySdtChanged` inside the command and waits on a
      Done button while the maintainer mines until dust falls. Inside the handler it records any firing
      whose `event:key()` is not a string, whose `event:gob():exists()` is false, or whose
      `event:sdt()` is empty or holds an entry not whole in `0..255`. On Done it reports one line for
      every invariant over all firings, with how many it saw. It fails if there were none. It passes
      a `gfx/fx/cavewarn` line printing the first byte of the newest member, and fails if no such
      firing came. It ends the subscription with `:off()`.
      `[manual]`: dust fell on screen while you mined — expect: yes.
