# 177 — Tasks

- [x] **177.1 — The client's own gobs leave the world surface.** `AddonManager.clientGob(Gob)` (an
      `OCache.Virtual`, never `Gob.virtual`), applied exactly as `plan.md` *Approach* writes it: both
      `getgob`s, `holds`, `allGobs`, `registerOcache`'s `added`/`removed` (before `armHold`),
      `nativeOverlayEvent` (after its `overlaySubs` check), and `queueOverlaySdtEvent`'s test.
      Docs: the `world.md` *Objects* rule row and the `event/bus/world.md` *Only objects the game sends*
      row, in the text `plan.md` gives. Covers criteria 1, 2, 3, 6.
      *Its suite* (`:t177`) subscribes, inside the command, `GobAdded`, `GobRemoved`, `GobOverlayAdded`,
      `GobOverlayRemoved` and `Update`, and opens a Done button while the maintainer walks somewhere new
      for about twenty seconds, past objects (a lit fire, animals, a mine). Each handler counts its
      firings and records the first whose `:gob():id()` is negative. Each `Update` samples
      `hafen.session():current():world():gob():list()` and records the first negative id; it counts its
      samples. On Done it ends every subscription with `:off()` and reports one line per event key
      ("no negative id among N"), one for the list ("no negative id in N samples"), one that
      `world():gob():get(-1):exists()` is `false`, one that a `GobAdded` with a positive id came, and one
      that a native `GobOverlayAdded` (`event:native()`) with a positive id came — each failing naming
      what was missing.
      `[manual]`: footsteps were heard while you walked — expect: yes.

- [x] **177.2 — The Overlay reads refuse a surplus argument.** In `LuaOverlay.methods`, `key`, `gob`,
      `native`, `res`, `kind`, `count`, `exists` and `info` become `VarArgFunction`s whose first line is
      `Args.only(a, 0, "overlay:<verb>")`, bodies otherwise unchanged; `sdt`'s comment drops its
      now-general sentence. No page changes: `conventions.md` already states that a surplus argument
      raises. Covers criteria 4 and 5.
      *Its suite* (`:t177`) waits on a Done button while the maintainer stands where the game draws
      overlays (a lit fire, a mine), then takes the first native overlay on any gob in view, failing
      naming "no native overlay in view" when there is none, and attaches `"t177"` (a text) to the
      player's gob. For each of the eight verbs, on both, it `pcall`s `ol[verb](ol, 1)` and requires a
      failure whose message holds `overlay:<verb>` and `no arguments`: one line per overlay naming every
      verb that did not refuse. Then bare: on the native one `:key()` is a string, `:gob():exists()`,
      `:native() == true`, `:res() == :key()`, `:kind() == nil`, `:count() >= 1`, `:exists()`,
      `type(:info()) == "table"`; on yours `:key() == "t177"`, `:native() == false`, `:res() == nil`,
      `:kind() == "text"`, `:count() == 1`, `:exists()`, `:info().kind == "text"` — one line per overlay
      naming the first that differs. It removes `"t177"`.
      `[manual]`: none.
