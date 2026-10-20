package io.brodgar.addon;

import haven.AWTCompat;
import haven.KeyMatch;
import haven.iosys.tk.Toolkit.KeyEvent;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * <b>Which keys are physically down right now</b> — the state behind {@code binding:down()}.
 *
 * <p><b>Why it has to exist.</b> A hotkey is an <i>edge</i>: {@code keybindings:on(name, fn)} runs when the
 * key goes down and there is no counterpart for it coming up. That is enough for a toggle and not enough for
 * anything a key is <i>held</i> for — walking, a push-to-talk, a modifier of your own — and the usual stand-in,
 * reading the desktop's key repeat as "still down", cannot be made to work: every desktop repeats <b>only the
 * key pressed last</b>, so W held while D is tapped stops repeating and never resumes, and two keys at once
 * are invisible. The level, not the edge, is what those need, and this is the level.
 *
 * <p><b>What is stored is the press itself.</b> The map holds the toolkit's {@link KeyEvent} that put each key down, so
 * {@link #matches} can hand it straight to {@link KeyMatch#match(KeyEvent)} — the very test the hotkey
 * dispatch does. There is no second reading of modifiers or of characters here to drift out of step with the
 * client's own. It also fixes the meaning of a modified binding in the one way that is useful for a held key:
 * a binding matches <b>the key as it was pressed</b>, so {@code Shift} taken up or let go afterwards neither
 * makes nor breaks a match, and a key held through it goes on reading down.
 *
 * <p><b>The seam is {@link LayerInput#offer}</b>, which offers every key of the frame to the addon layer before
 * the session is given what is left, and is the one place both edges of a key pass through.
 * A key repeat re-puts the same entry, so it is idempotent; a release removes it.
 *
 * <p><b>Focus is what makes it safe.</b> A key held while the window loses focus has its release delivered to
 * whatever took the focus, so the entry would be stranded down for ever — the classic stuck key, and here it
 * would be a character walking off with nothing to stop it. {@link #clear()} is therefore called from the
 * frame's offer of its input whenever the window is not focused, so an alt-tab lets go of everything.
 *
 * <p>A key the toolkit cannot name a virtual code for is not tracked, and reads as up: this is keyed by the
 * physical key, and a code of {@code VK_UNDEFINED} names every such key at once rather than one of them.
 */
public final class KeyHeld {
    /** The press that put each key down, by virtual key code ({@link #code}). Guarded by itself. */
    private static final Map<Integer, KeyEvent> held = new HashMap<Integer, KeyEvent>();

    private KeyHeld() {
    }

    /** A key went down (or repeated, which re-puts the same entry). */
    public static void down(KeyEvent ev) {
        int code = code(ev);
        if(code == java.awt.event.KeyEvent.VK_UNDEFINED)
            return;
        synchronized(held) {
            held.put(code, ev);
        }
    }

    /** A key came up. */
    public static void up(KeyEvent ev) {
        int code = code(ev);
        if(code == java.awt.event.KeyEvent.VK_UNDEFINED)
            return;
        synchronized(held) {
            held.remove(code);
        }
    }

    /** The virtual key code of the key an event is about, as the client's AWT form of it reads it. */
    private static int code(KeyEvent ev) {
        return AWTCompat.mkawt(ev).getKeyCode();
    }

    /** Let go of everything — the window lost focus, so the releases are going somewhere else. */
    public static void clear() {
        synchronized(held) {
            if(!held.isEmpty())
                held.clear();
        }
    }

    /**
     * Is any key that is down right now the one {@code km} fires on? {@code null} and {@link KeyMatch#nil}
     * (an unbound binding) never match, exactly as they never fire.
     */
    static boolean matches(KeyMatch km) {
        if((km == null) || (km == KeyMatch.nil))
            return false;
        List<KeyEvent> now;
        synchronized(held) {
            if(held.isEmpty())
                return false;
            now = new ArrayList<KeyEvent>(held.values());
        }
        for(KeyEvent ev : now) {
            if(km.match(ev))
                return true;
        }
        return false;
    }
}
