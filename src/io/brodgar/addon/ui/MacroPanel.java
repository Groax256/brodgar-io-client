package io.brodgar.addon.ui;

import haven.Button;
import haven.Coord;
import haven.GOut;
import haven.Label;
import haven.Loading;
import haven.OptWnd;
import haven.Resource;
import haven.SListBox;
import haven.SListWidget;
import haven.Tex;
import haven.TextEntry;
import haven.UI;
import haven.Widget;
import haven.Window;

import io.brodgar.addon.AddonManager;
import io.brodgar.addon.Macro;
import io.brodgar.addon.Macros;
import io.brodgar.ui.CodeArea;

import java.util.List;

/**
 * The <b>Macros</b> page of the game menu (174): the player's own Lua snippets, kept by the client
 * ({@link Macros}). On the left a list of every macro, its icon and its name; on the right, for the one
 * selected, its icon, its name, a {@link CodeArea} holding its body and a status line, then <b>New</b>,
 * <b>Save</b>, <b>Delete</b> and <b>Run</b>, and <b>Back</b> under everything. Run saves, then runs the body
 * as a {@code :lua} line runs ({@link AddonManager#runMacro}).
 *
 * <p><b>Saving.</b> Save stores the name and the body, and refuses an empty name on the status line. Whatever
 * takes the fields away from a macro stores them first — another row picked, New, Delete of another, the page
 * leaving the screen (Back, the window closed, the menu reopened) and the page destroyed with its window —
 * and there an empty name keeps the name already stored, so nothing typed is lost. Delete asks first, in a
 * window of its own.
 *
 * <p>Like {@link AddonPanel} it holds no listener: it polls {@link Macros#gen} every tick, so a list written
 * from anywhere is the list it shows. Rows are {@link MacroRow}s, each a {@link Label} beside the icon, so a
 * row is read back by its name.
 */
public class MacroPanel extends OptWnd.Panel {
    /** The list's width, the editor's box, the icon's box, a row's height, the gap between the columns, a button. */
    static final int LIST_W = 200, EDIT_W = 440, EDIT_H = 300, ICON = 36, ROW_H = 24, GAP = 10, BUTTON_W = 100;
    /** What the status line says when Save meets an empty name. */
    static final String NEED_NAME = "Give the macro a name to save it.";

    private final MacroList list;
    private final MacroIcon icon;
    private final TextEntry name;
    private final CodeArea area;
    private final Label status;
    private final Button save, delete, run;
    private List<Macro> items = Macros.all();
    private int seen = Macros.gen();
    private Macro editing = null;          // the macro the fields hold, or null
    private boolean shown = false;         // on screen at the last tick
    private Window confirm = null;         // Delete's question, while it stands

    public MacroPanel(OptWnd opt, OptWnd.Panel back) {
        opt.super("Macros");
        int x = UI.scale(LIST_W + GAP);
        icon = add(new MacroIcon(UI.scale(new Coord(ICON, ICON))), new Coord(x, 0));
        name = add(new TextEntry(UI.scale(EDIT_W - ICON - 8), ""),
                   new Coord(x + UI.scale(ICON + 8), (icon.sz.y - TextEntry.bgheight()) / 2));
        area = add(new CodeArea(UI.scale(new Coord(EDIT_W, EDIT_H)), Macros.MAX_BODY),
                   new Coord(x, icon.sz.y + UI.scale(6)));
        status = add(new Label(""), new Coord(x, area.c.y + area.sz.y + UI.scale(6)));
        int by = status.c.y + status.sz.y + UI.scale(6);
        Button nb = add(new Button(UI.scale(BUTTON_W), "New", false).action(this::create), new Coord(x, by));
        save = add(new Button(UI.scale(BUTTON_W), "Save", false).action(this::save), nb.pos("ur").adds(GAP, 0));
        delete = add(new Button(UI.scale(BUTTON_W), "Delete", false).action(this::ask), save.pos("ur").adds(GAP, 0));
        run = add(new Button(UI.scale(BUTTON_W), "Run", false).action(this::run), delete.pos("ur").adds(GAP, 0));
        list = add(new MacroList(new Coord(UI.scale(LIST_W), nb.c.y + nb.sz.y)), new Coord(0, 0));
        add(opt.new PButton(UI.scale(200), "Back", 27, back), list.pos("bl").adds(0, 8));
        pack();
        open(items.isEmpty() ? null : items.get(0));
    }

    // ---- what the fields hold --------------------------------------------------------------------

    /** Re-read the list when it was written, and follow the macro being edited into it. */
    private void sync() {
        if(Macros.gen() == seen)
            return;
        seen = Macros.gen();
        items = Macros.all();
        if(editing != null) {
            Macro now = Macros.get(editing.id);
            if(now == null) {
                editing = null;
                open(items.isEmpty() ? null : items.get(0));
                return;
            }
            editing = now;
        }
        list.sel = editing;
    }

    /**
     * Store the fields on the macro being edited. {@code explicit} is Save: an empty name is refused there,
     * saying why. Anywhere else an empty name stores the body under the name already stored, and the field
     * reads that name again. Answers whether the fields are stored.
     */
    private boolean commit(boolean explicit) {
        if(editing == null)
            return true;
        String n = name.text().trim();
        if(n.isEmpty()) {
            if(explicit) {
                status.settext(NEED_NAME);
                return false;
            }
            n = editing.name;
            name.settext(n);
        }
        Macro saved = Macros.save(editing.id, n, area.text());
        sync();
        return saved != null;
    }

    /** Put {@code m} in the fields, after storing what they held. {@code null} empties the page. */
    private void open(Macro m) {
        commit(false);
        sync();
        Macro cur = (m == null) ? null : Macros.get(m.id);
        editing = cur;
        list.sel = cur;
        if(cur != null) {
            name.settext(cur.name);
            area.text(cur.body);
            icon.icon = cur.icon;
            list.display(cur);
            status.settext("");
        } else {
            name.settext("");
            area.text("");
            icon.icon = null;
            status.settext(items.isEmpty() ? "No macros yet. Press New to make one." : "");
        }
        for(Widget w : new Widget[] {icon, name, area, save, delete, run})
            w.show(cur != null);
    }

    // ---- the buttons -----------------------------------------------------------------------------

    private void create() {
        commit(false);
        Macro m = Macros.create();
        sync();
        open(m);
        setfocus(name);
        name.buf.select(0, name.buf.length());
    }

    private void save() {
        if(editing == null)
            return;
        if(commit(true))
            status.settext("Saved.");
    }

    /** Save, then run the body in the {@code :lua} console's runtime. An empty name is refused, and nothing runs. */
    private void run() {
        if(editing == null)
            return;
        if(!commit(true))
            return;
        status.settext("");
        AddonManager.runMacro(editing.id);
    }

    /** Delete's question, in a window of its own over everything. */
    private void ask() {
        if(editing == null)
            return;
        closeConfirm();
        final int id = editing.id;
        Window w = new Window(Coord.z, "Delete macro");
        Label q = w.add(new Label("Delete macro \"" + editing.name + "\"?"), new Coord(0, 0));
        Button yes = w.add(new Button(UI.scale(80), "Yes", false).action(() -> {
                    closeConfirm();
                    remove(id);
                }), q.pos("bl").adds(0, 10));
        w.add(new Button(UI.scale(80), "No", false).action(this::closeConfirm), yes.pos("ur").adds(10, 0));
        w.reqclose(this::closeConfirm);
        w.pack();
        confirm = ui.root.adda(w, ui.root.sz.div(2), 0.5, 0.5);
        confirm.raise();
    }

    private void closeConfirm() {
        if((confirm != null) && (confirm.parent != null))
            confirm.destroy();
        confirm = null;
    }

    /** Delete the macro of {@code id}; the fields move to its neighbour in the list. */
    private void remove(int id) {
        int at = 0;
        for(int i = 0; i < items.size(); i++) {
            if(items.get(i).id == id)
                at = i;
        }
        if((editing != null) && (editing.id == id))
            editing = null;
        Macros.delete(id);
        sync();
        open(items.isEmpty() ? null : items.get(Math.min(at, items.size() - 1)));
    }

    // ---- the page coming and going ---------------------------------------------------------------

    public void tick(double dt) {
        super.tick(dt);
        sync();
        // The window closed with this page showing hides the window, never this page: the edge is read here.
        boolean on = tvisible();
        if(shown && !on) {
            commit(false);
            closeConfirm();
        }
        shown = on;
    }

    public void hide() {
        commit(false);
        closeConfirm();
        super.hide();
    }

    public void destroy() {
        commit(false);
        closeConfirm();
        super.destroy();
    }

    // ---- the widgets -----------------------------------------------------------------------------

    /** Draw the first image of the resource {@code res} fitted in {@code box} at {@code ul}; nothing while it loads. */
    static void drawIcon(GOut g, String res, Coord ul, Coord box) {
        if(res == null)
            return;
        try {
            Tex tex = Resource.local().load(res).get().flayer(Resource.imgc).tex();
            Coord ts = tex.sz();
            double s = Math.min((double)box.x / ts.x, (double)box.y / ts.y);
            Coord d = Coord.of(Math.max(1, (int)Math.round(ts.x * s)), Math.max(1, (int)Math.round(ts.y * s)));
            g.image(tex, ul.add(box.sub(d).div(2)), d);
        } catch(Loading l) {
            /* drawn once it has loaded */
        }
    }

    /** The macro's icon on the page. */
    public static class MacroIcon extends Widget {
        String icon;

        MacroIcon(Coord sz) {
            super(sz);
        }

        public void draw(GOut g) {
            g.chcolor(0, 0, 0, 128);
            g.frect(Coord.z, sz);
            g.chcolor();
            drawIcon(g, icon, Coord.of(UI.scale(2)), sz.sub(UI.scale(4), UI.scale(4)));
        }
    }

    /** One row of the list: the macro's icon, then its name as a {@link Label}. */
    public static class MacroRow extends SListWidget.ItemWidget<Macro> {
        MacroRow(SListWidget<Macro, ?> list, Coord sz, Macro m) {
            super(list, sz, m);
            Label l = new Label(m.name);
            add(l, new Coord(sz.y + UI.scale(4), (sz.y - l.sz.y) / 2));
        }

        public void draw(GOut g) {
            drawIcon(g, item.icon, Coord.of(UI.scale(2)), Coord.of(sz.y - UI.scale(4)));
            super.draw(g);
        }
    }

    /** The list: a click on a row opens it, and a click on empty space keeps the one open. */
    private class MacroList extends SListBox<Macro, Widget> {
        MacroList(Coord sz) {
            super(sz, UI.scale(ROW_H));
        }

        protected List<Macro> items() {
            return items;
        }

        protected Widget makeitem(Macro m, int idx, Coord sz) {
            return new MacroRow(this, sz, m);
        }

        public void change(Macro m) {
            if((m != null) && ((editing == null) || (m.id != editing.id)))
                open(m);
        }

        protected boolean unselect(int button) {
            return true;
        }
    }
}
