package io.brodgar.addon;

import haven.Debug;
import haven.UI;
import haven.Utils;
import haven.Widget;
import haven.iosys.tk.Key;
import haven.iosys.tk.MouseBtn;
import haven.iosys.tk.Toolkit;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * The addon layer's half of the input (074.1): every event of the frame is offered to the layer FIRST, and
 * the session on screen is handed exactly what the layer did not consume.
 *
 * <p><b>It runs before the client's own dispatch, never inside it.</b> {@code Client.EventQueue} parks what
 * comes in until {@link #offer} has seen it, and moves on into the client's own queue what is left, so
 * {@code EventQueue.dispatch(ui)} -- upstream's, unchanged -- delivers to the session only what the layer was
 * offered and declined. It holds the layer's monitor and nothing else: the session's is taken afterwards, by
 * the frame, around that dispatch, and the two are never nested (docs/client/multi-session.md's one lock
 * direction). Within one frame the layer therefore sees its events before the session sees its own; each
 * tree still sees its events in the order they came.
 *
 * <p><b>The layer is fed through {@code UI.dispatch(root, ev)}, not through
 * {@code UI.keydown} and the rest</b>, because those answer nothing, and "the session only if the layer did
 * not take it" needs the answer. What they do besides the dispatch -- the modifier state, {@code mc} and
 * {@code lcc}, the button number -- is done here the same way.
 */
public final class LayerInput {
    /**
     * Which tree took the press of each mouse button, so that its RELEASE goes to the same one. Layer-first is
     * the rule for a press, and it would be wrong for the release that ends a drag: a camera pan begun on the
     * world and let go over an addon window must still reach the tree that is panning, or the drag never ends.
     * 0 = nobody pressed it, 1 = the layer, 2 = the session.
     */
    private final int[] btnowner = new int[4];

    /**
     * Offer {@code mv} and {@code evs} to {@code layer}, and answer the events the session is to be given, in
     * their order. A move is not a claim, so the layer is moved and the move is left for the session too.
     * {@code ui} is the session's tree: an event the layer consumes still counts as the session's last input,
     * as it did when one dispatch fed both.
     */
    public List<Toolkit.Event> offer(UI layer, UI ui, Toolkit.MouseMoveEvent mv, List<Toolkit.Event> evs) {
        /* A MOVE IS NOT A CLAIM, so both trees get every one of them. It is how a widget un-hovers when the
         * pointer leaves it and how each tree learns where the pointer is, and the client's own dispatch
         * already broadcasts it to every child rather than stopping at the first. */
        if(mv != null) {
            synchronized(layer) {
                layer.mousemove(mv);
            }
        }
        List<Toolkit.Event> left = new ArrayList<Toolkit.Event>(evs.size());
        for(Toolkit.Event ev : evs) {
            /* WHICH KEYS ARE DOWN (binding:down()). Both edges of every key pass through here and nowhere
             * else, and a hotkey is an edge, so this is the one place the LEVEL can be kept. Recorded before
             * the dispatch and for every key, taken or not: a key held down is held down whichever tree the
             * press went to. */
            if(ev instanceof Toolkit.KeyDownEvent)
                KeyHeld.down((Toolkit.KeyEvent)ev);
            else if(ev instanceof Toolkit.KeyUpEvent)
                KeyHeld.up((Toolkit.KeyEvent)ev);
            boolean took;
            synchronized(layer) {
                took = take(layer, ev);
            }
            if(took) {
                if(ev instanceof Toolkit.KeyEvent)
                    Debug.keyevent((Toolkit.KeyEvent)ev);
                ui.lastevent = Utils.rtime();
            } else {
                left.add(ev);
            }
        }
        return left;
    }

    /** Whether the layer consumed {@code ev}, which the session is then not given. */
    private boolean take(UI layer, Toolkit.Event ev) {
        if(ev instanceof Toolkit.MouseDownEvent) {
            Toolkit.MouseDownEvent e = (Toolkit.MouseDownEvent)ev;
            int btn = buttonid(e.button());
            if(btn == 0)
                return false;
            mods(layer, e.mods());
            boolean took = layer.dispatch(layer.root, new Widget.MouseDownEvent(layer.lcc = layer.mc = e.wndc(), btn));
            /* The press went to the session, so the layer above it gives up the focus -- otherwise one click on
             * an addon window keeps Escape and Tab in the layer for the rest of the client's life. */
            if(!took)
                layer.root.clearfocus();
            btnowner[btn] = took ? 1 : 2;
            return took;
        } else if(ev instanceof Toolkit.MouseUpEvent) {
            Toolkit.MouseUpEvent e = (Toolkit.MouseUpEvent)ev;
            int btn = buttonid(e.button());
            if(btn == 0)
                return false;
            int owner = btnowner[btn];
            btnowner[btn] = 0;
            if(owner == 2)
                return false;
            mods(layer, e.mods());
            boolean took = layer.dispatch(layer.root, new Widget.MouseUpEvent(layer.mc = e.wndc(), btn));
            return took || (owner == 1);
        } else if(ev instanceof Toolkit.MouseWheelEvent) {
            Toolkit.MouseWheelEvent e = (Toolkit.MouseWheelEvent)ev;
            if(e.axis() != Toolkit.MouseWheelEvent.Axis.VERT)
                return false;
            mods(layer, e.mods());
            return layer.dispatch(layer.root, new Widget.MouseWheelEvent(layer.mc = e.wndc(), e.amount(), e.subamount()));
        } else if(ev instanceof Toolkit.KeyDownEvent) {
            /* The FOCUSED half of a key press alone, without the global fallback. RootWidget answers a
             * GlobKeyEvent for every printable key with a "gk" message and consumes it, so a layer handed the
             * whole of a key press would swallow the keyboard from the session under it. A global key belongs
             * to the game; a focused one belongs to whatever holds focus. */
            Toolkit.KeyDownEvent e = (Toolkit.KeyDownEvent)ev;
            mods(layer, e.mods());
            return layer.dispatch(layer.root, new Widget.KeyDownEvent(e));
        } else if(ev instanceof Toolkit.KeyUpEvent) {
            Toolkit.KeyUpEvent e = (Toolkit.KeyUpEvent)ev;
            mods(layer, e.mods());
            return layer.dispatch(layer.root, new Widget.KeyUpEvent(e));
        }
        return false;
    }

    /** {@code UI.setmods}, which is private: the modifier state an event carries, on the tree it is delivered to. */
    private static void mods(UI ui, Set<Key.Mod> mods) {
        ui.modshift = mods.contains(Key.Mod.SHIFT);
        ui.modctrl = mods.contains(Key.Mod.CONTROL);
        ui.modmeta = mods.contains(Key.Mod.ALT) || mods.contains(Key.Mod.META);
        ui.modsuper = mods.contains(Key.Mod.SUPER);
    }

    /** {@code UI.buttonid}, which is private: the client's button number, 0 for a button it has none for. */
    private static int buttonid(MouseBtn btn) {
        if(btn == MouseBtn.Std.LEFT)
            return 1;
        else if(btn == MouseBtn.Std.MIDDLE)
            return 2;
        else if(btn == MouseBtn.Std.RIGHT)
            return 3;
        return 0;
    }
}
