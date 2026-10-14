package io.brodgar.addon;

import haven.UI;
import haven.Widget;

/**
 * <b>A surface that does not exist for addons</b> (175.1) — worn by the Macros page and by its Delete question.
 * A macro runs in the console's Lua, unsandboxed, so a page that shows and edits one is a way out of every
 * addon's sandbox the moment an addon can read it, write it or follow the keys typed into it.
 *
 * <p>The marker is per class, never per instance: the menu builds a fresh page on every press of its button.
 * A widget is hidden when it or any ancestor wears it, and every door of the addon layer asks the one question
 * {@link #is}: {@link LuaWidget#of} (the backstop), the selector walk and the subtree walks in {@link UiApi},
 * {@code :children()} and {@code :walk()}, the hit test and {@code tipAt}, the stylesheet's
 * {@code consentSurface}, and the keyboard through {@link #typing}. It is one rule for every Lua owner, the
 * {@code :lua} console included.
 */
public interface AddonHidden {
    /** The longest focus chain {@link #typing} follows: {@code focused} is never checked against the tree. */
    int CHAIN = 64;

    /** True when {@code w} or any of its ancestors wears the marker. */
    static boolean is(Widget w) {
        for(Widget p = w; p != null; p = p.parent) {
            if(p instanceof AddonHidden)
                return true;
        }
        return false;
    }

    /**
     * True when the keyboard focus of {@code u} ends inside a hidden surface. It follows {@code focused} from
     * the root through every focus controller, as the focused-key delivery does; {@code hasfocus} is not
     * maintained there, and {@code Widget.setfocus} forwards to the nearest controller, so the Options window
     * records the page's editor or name field directly. The walk is bounded, because a controller may hold a
     * {@code focused} that points back into its own chain.
     */
    static boolean typing(UI u) {
        if((u == null) || (u.root == null))
            return false;
        Widget w = u.root;
        for(int i = 0; (i < CHAIN) && w.focusctl && (w.focused != null) && (w.focused != w); i++)
            w = w.focused;
        return is(w);
    }
}
