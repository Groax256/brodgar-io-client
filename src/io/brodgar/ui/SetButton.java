package io.brodgar.ui;

import haven.Coord;
import haven.GOut;
import haven.KeyBinding;
import haven.KeyMatch;
import haven.OptWnd;
import haven.Widget;
import haven.iosys.tk.Key;

/**
 * The key button that stands anywhere (163.1): the row Options ▸ Game ▸ Keybindings ends in, built outside an
 * Options window -- {@code hafen.ui():keybinding()} builds it on an addon's own page. The panel's own is
 * {@code OptWnd.BindingPanel.SetButton}, an inner class of the panel and so buildable only inside one; this is
 * the same button with what standing alone needs: {@code cmd} may be null and may be re-pointed, a button bound
 * to nothing shows the key it last showed and writes nothing, and {@link #follow} is the display half of
 * {@code draw}, callable at once. It has the panel's class name on purpose: an addon reads both as
 * {@code :type()} {@code "SetButton"}.
 */
public class SetButton extends KeyMatch.Capture {
    /** The binding the button edits, or null while it is joined to none. */
    public KeyBinding cmd;

    public SetButton(int w, KeyBinding cmd) {
        super(w, (cmd == null) ? null : cmd.key());   // bound to nothing, it reads None
        this.cmd = cmd;
    }

    public void set(KeyMatch key) {
        super.set(key);
        if(cmd != null)
            cmd.set(key);
    }

    /**
     * Show the binding's key WITHOUT writing it -- the panel's own {@code draw} test, by identity as it is there:
     * {@link KeyBinding#key()} hands out one cached wrapper per key, so a new object means a new key.
     */
    public void follow() {
        if((cmd != null) && (cmd.key() != key))
            super.set(cmd.key());
    }

    public void draw(GOut g) {
        follow();
        super.draw(g);
    }

    protected KeyMatch mkmatch(Widget.KeyDownEvent ev) {
        return(KeyMatch.forevent(ev, ~((cmd == null) ? 0 : cmd.modign)));
    }

    protected boolean handle(Widget.KeyDownEvent ev) {
        if(ev.tkev().sym() == Key.Std.BACKSPACE) {
            if(cmd != null) {   // bound to nothing, there is no default to go back to
                cmd.set(null);
                super.set(cmd.key());
            }
            return(true);
        }
        return(super.handle(ev));
    }

    public Object tooltip(Coord c, Widget prev) {
        return(OptWnd.kbtt().tex());
    }
}
