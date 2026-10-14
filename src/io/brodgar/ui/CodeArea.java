package io.brodgar.ui;

import haven.Coord;
import haven.Fonts;
import haven.GOut;
import haven.KeyMatch;
import haven.ReadLine;
import haven.Scrollable;
import haven.Scrollbar;
import haven.Text;
import haven.TextEntry;
import haven.UI;
import haven.Utils;
import haven.Widget;
import haven.iosys.tk.Clipboard;

import java.awt.Color;
import java.awt.event.KeyEvent;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

/**
 * <b>A multi-line code editor</b> (174): a body of text held as lines, a caret and an anchor as (line, column),
 * set in a monospaced face, with a vertical {@link Scrollbar}. The client's own {@link TextEntry} is one line
 * and Enter submits it, so this is its own widget.
 *
 * <p>The keys: typing (an AltGr character included), Enter a new line, Tab two spaces, Backspace and Delete,
 * the arrows (Ctrl for a word), Home and End (Ctrl for the body), PgUp and PgDn; Shift with any move extends
 * the selection; Ctrl+A selects everything, Ctrl+C, Ctrl+X and Ctrl+V go through the system clipboard. A
 * click places the caret, a drag or a Shift+click selects, the wheel and the bar scroll. Escape is left to
 * the window, and a key reaching the editor while it is not on screen is left alone. The body never grows
 * past {@link #max} characters, newlines counted.
 *
 * <p>Its text is what the user typed: the lines render inside {@link Fonts#enterTyped}, so a catalogue never
 * rewrites a word of it, under the {@code textentry} scope a theme dresses fields with.
 */
public class CodeArea extends Widget implements Scrollable {
    public static final Text.Foundry fnd = new Text.Foundry(Text.mono, 11).aa(true);
    public static final Color bgcol = new Color(0, 0, 0, 160), fgcol = new Color(225, 225, 225);
    /** What Tab inserts. */
    public static final String TAB = "  ";
    private static final int PAD = UI.scale(4);

    /** The longest body, in characters with the newlines. */
    public final int max;
    private final List<String> lines = new ArrayList<String>();
    private int len = 0;
    private int cl = 0, cc = 0;            // the caret
    private int al = -1, ac = 0;           // the anchor, the selection's other end; al < 0 is no selection
    private int goal = -1;                 // the column Up and Down aim for, while they repeat
    private int sy = 0, sx = 0;            // the scroll, in pixels
    private int lineh = Math.max(1, fnd.height());
    private double mtime = 0;              // the caret's last move, which its blink counts from
    private final Scrollbar sb;
    private UI.Grab drag = null;
    private Map<String, Text.Line> cache = new HashMap<String, Text.Line>();
    private int fontgen = -1;

    public CodeArea(Coord sz, int max) {
        super(sz);
        this.max = max;
        lines.add("");
        sb = add(new Scrollbar(sz.y, this));
        sb.c = Coord.of(sz.x - sb.sz.x, 0);
        setcanfocus(true);
    }

    // ---- the body --------------------------------------------------------------------------------

    /** The body: the lines joined by {@code \n}. */
    public String text() {
        return String.join("\n", lines);
    }

    /** Replace the body; the caret goes to its start, the selection and the scroll are dropped. */
    public void text(String text) {
        String s = clean(text);
        if(s.length() > max)
            s = s.substring(0, max);
        lines.clear();
        for(String l : s.split("\n", -1))
            lines.add(l);
        len = s.length();
        cl = cc = 0;
        al = -1;
        goal = -1;
        sy = sx = 0;
        mtime = Utils.rtime();
    }

    /** {@code \r\n} and {@code \r} as {@code \n}, a tab as {@link #TAB}, every other control character dropped. */
    static String clean(String text) {
        if(text == null)
            return "";
        StringBuilder b = new StringBuilder(text.length());
        for(int i = 0; i < text.length(); i++) {
            char c = text.charAt(i);
            if(c == '\r') {
                b.append('\n');
                if((i + 1 < text.length()) && (text.charAt(i + 1) == '\n'))
                    i++;
            } else if(c == '\n') {
                b.append('\n');
            } else if(c == '\t') {
                b.append(TAB);
            } else if((c >= 32) && (c != 127)) {
                b.append(c);
            }
        }
        return b.toString();
    }

    private boolean hassel() {
        return (al >= 0) && ((al != cl) || (ac != cc));
    }

    /** The selection as {line, column, line, column}, its start first. */
    private int[] sel() {
        if((al < cl) || ((al == cl) && (ac < cc)))
            return new int[] {al, ac, cl, cc};
        return new int[] {cl, cc, al, ac};
    }

    private String seltext() {
        int[] s = sel();
        if(s[0] == s[2])
            return lines.get(s[0]).substring(s[1], s[3]);
        StringBuilder b = new StringBuilder(lines.get(s[0]).substring(s[1]));
        for(int i = s[0] + 1; i < s[2]; i++)
            b.append('\n').append(lines.get(i));
        return b.append('\n').append(lines.get(s[2]), 0, s[3]).toString();
    }

    /** Remove from (l0, c0) to (l1, c1), the first before the second; the caret goes to (l0, c0). */
    private void remove(int l0, int c0, int l1, int c1) {
        String first = lines.get(l0), last = lines.get(l1);
        int gone;
        if(l0 == l1) {
            gone = c1 - c0;
        } else {
            gone = (first.length() - c0) + 1 + c1;
            for(int i = l0 + 1; i < l1; i++)
                gone += lines.get(i).length() + 1;
        }
        lines.set(l0, first.substring(0, c0) + last.substring(c1));
        if(l1 > l0)
            lines.subList(l0 + 1, l1 + 1).clear();
        len -= gone;
        cl = l0;
        cc = c0;
        al = -1;
    }

    private void delsel() {
        int[] s = sel();
        remove(s[0], s[1], s[2], s[3]);
    }

    /** Insert {@code s}, already {@link #clean}, over the selection — cut short at {@link #max}. */
    private void insert(String s) {
        if(hassel())
            delsel();
        al = -1;
        int room = max - len;
        if(room <= 0)
            return;
        if(s.length() > room)
            s = s.substring(0, room);
        String cur = lines.get(cl);
        String head = cur.substring(0, cc), tail = cur.substring(cc);
        String[] parts = s.split("\n", -1);
        if(parts.length == 1) {
            lines.set(cl, head + s + tail);
            cc += s.length();
        } else {
            lines.set(cl, head + parts[0]);
            for(int i = 1; i < parts.length - 1; i++)
                lines.add(cl + i, parts[i]);
            lines.add(cl + parts.length - 1, parts[parts.length - 1] + tail);
            cl += parts.length - 1;
            cc = parts[parts.length - 1].length();
        }
        len += s.length();
    }

    // ---- the caret -------------------------------------------------------------------------------

    /** Put the caret at (l, c), clamped; with {@code extend} the anchor stays where the caret was. */
    private void move(int l, int c, boolean extend) {
        if(extend) {
            if(al < 0) {
                al = cl;
                ac = cc;
            }
        } else {
            al = -1;
        }
        cl = Utils.clip(l, 0, lines.size() - 1);
        cc = Utils.clip(c, 0, lines.get(cl).length());
    }

    private static boolean word(char c) {
        return Character.isLetterOrDigit(c) || (c == '_');
    }

    private int[] wordleft() {
        if(cc == 0)
            return (cl > 0) ? new int[] {cl - 1, lines.get(cl - 1).length()} : new int[] {0, 0};
        String l = lines.get(cl);
        int c = cc;
        while((c > 0) && !word(l.charAt(c - 1))) c--;
        while((c > 0) && word(l.charAt(c - 1))) c--;
        return new int[] {cl, c};
    }

    private int[] wordright() {
        String l = lines.get(cl);
        if(cc == l.length())
            return (cl < lines.size() - 1) ? new int[] {cl + 1, 0} : new int[] {cl, cc};
        int c = cc;
        while((c < l.length()) && !word(l.charAt(c))) c++;
        while((c < l.length()) && word(l.charAt(c))) c++;
        return new int[] {cl, c};
    }

    /** How many lines one PgUp or PgDn moves. */
    private int page() {
        return Math.max(1, ((sz.y - (2 * PAD)) / lineh) - 1);
    }

    /** The width the text has, left of the bar. */
    private int textw() {
        return sz.x - sb.sz.x - (2 * PAD);
    }

    /** Scroll so the caret is on screen. */
    private void follow() {
        int top = cl * lineh;
        if(top < sy)
            sy = top;
        else if(top + lineh > sy + sz.y - (2 * PAD))
            sy = top + lineh - (sz.y - (2 * PAD));
        clampscroll();
        int x = render(lines.get(cl)).advance(cc);
        int w = textw();
        if(x < sx)
            sx = x;
        else if(x > sx + w - UI.scale(2))
            sx = x - w + UI.scale(2);
        if(sx < 0)
            sx = 0;
        mtime = Utils.rtime();
    }

    private void clampscroll() {
        sy = Utils.clip(sy, 0, scrollmax());
    }

    public int scrollmin() {
        return 0;
    }

    public int scrollmax() {
        return Math.max(0, (lines.size() * lineh) + (2 * PAD) - sz.y);
    }

    public int scrollval() {
        return sy;
    }

    public void scrollval(int val) {
        sy = val;
        clampscroll();
    }

    // ---- the keys --------------------------------------------------------------------------------

    public boolean keydown(KeyDownEvent ev) {
        if(!tvisible())
            return false;
        int code = ev.code;
        char c = ev.c;
        boolean shift = (ev.mods & KeyMatch.S) != 0;
        int mod = ev.mods & ~KeyMatch.S;
        boolean vertical = false;
        if((code == KeyEvent.VK_ENTER) && (mod == 0)) {
            insert("\n");
        } else if((code == KeyEvent.VK_TAB) && (mod == 0) && !shift) {
            insert(TAB);
        } else if((code == KeyEvent.VK_BACK_SPACE) && (mod == 0)) {
            if(hassel())
                delsel();
            else if(cc > 0)
                remove(cl, cc - 1, cl, cc);
            else if(cl > 0)
                remove(cl - 1, lines.get(cl - 1).length(), cl, 0);
        } else if((code == KeyEvent.VK_DELETE) && (mod == 0)) {
            if(hassel())
                delsel();
            else if(cc < lines.get(cl).length())
                remove(cl, cc, cl, cc + 1);
            else if(cl < lines.size() - 1)
                remove(cl, cc, cl + 1, 0);
        } else if((code == KeyEvent.VK_LEFT) && (mod == 0)) {
            if(!shift && hassel()) {
                int[] s = sel();
                move(s[0], s[1], false);
            } else if(cc > 0) {
                move(cl, cc - 1, shift);
            } else if(cl > 0) {
                move(cl - 1, lines.get(cl - 1).length(), shift);
            } else {
                move(cl, cc, shift);
            }
        } else if((code == KeyEvent.VK_RIGHT) && (mod == 0)) {
            if(!shift && hassel()) {
                int[] s = sel();
                move(s[2], s[3], false);
            } else if(cc < lines.get(cl).length()) {
                move(cl, cc + 1, shift);
            } else if(cl < lines.size() - 1) {
                move(cl + 1, 0, shift);
            } else {
                move(cl, cc, shift);
            }
        } else if((code == KeyEvent.VK_LEFT) && (mod == KeyMatch.C)) {
            int[] w = wordleft();
            move(w[0], w[1], shift);
        } else if((code == KeyEvent.VK_RIGHT) && (mod == KeyMatch.C)) {
            int[] w = wordright();
            move(w[0], w[1], shift);
        } else if(((code == KeyEvent.VK_UP) || (code == KeyEvent.VK_DOWN) || (code == KeyEvent.VK_PAGE_UP)
                   || (code == KeyEvent.VK_PAGE_DOWN)) && (mod == 0)) {
            if(goal < 0)
                goal = cc;
            int step = ((code == KeyEvent.VK_UP) || (code == KeyEvent.VK_DOWN)) ? 1 : page();
            int to = cl + (((code == KeyEvent.VK_UP) || (code == KeyEvent.VK_PAGE_UP)) ? -step : step);
            if(to < 0)
                move(0, 0, shift);
            else if(to > lines.size() - 1)
                move(lines.size() - 1, lines.get(lines.size() - 1).length(), shift);
            else
                move(to, goal, shift);
            vertical = true;
        } else if((code == KeyEvent.VK_HOME) && (mod == 0)) {
            move(cl, 0, shift);
        } else if((code == KeyEvent.VK_END) && (mod == 0)) {
            move(cl, lines.get(cl).length(), shift);
        } else if((code == KeyEvent.VK_HOME) && (mod == KeyMatch.C)) {
            move(0, 0, shift);
        } else if((code == KeyEvent.VK_END) && (mod == KeyMatch.C)) {
            move(lines.size() - 1, lines.get(lines.size() - 1).length(), shift);
        } else if((c == 'a') && (mod == KeyMatch.C)) {
            move(0, 0, false);
            move(lines.size() - 1, lines.get(lines.size() - 1).length(), true);
        } else if(((c == 'c') || (c == 'x')) && (mod == KeyMatch.C)) {
            if(!hassel())
                return true;
            clipboard().put(new Clipboard.Contents(new Clipboard.Item<CharSequence>(Clipboard.Format.TEXT, seltext())));
            if(c == 'x')
                delsel();
        } else if((c == 'v') && (mod == KeyMatch.C)) {
            ReadLine.PCLine.cliptext(clipboard()).map(this::paste).report(ui, "Clipboard error");
            return true;
        } else if((c >= 32) && (c != 127) && ((mod == 0) || (mod == (KeyMatch.C | KeyMatch.M)))) {
            // Ctrl+Alt is how AltGr arrives: the characters a keyboard layout puts there are typed text
            insert(String.valueOf(c));
        } else {
            return false;
        }
        if(!vertical)
            goal = -1;
        follow();
        return true;
    }

    private Clipboard clipboard() {
        return ui.wnd.clipboard(Clipboard.Std.CLIPBOARD);
    }

    /** What the clipboard held, inserted at the caret: called back from wherever the clipboard answers. */
    private void paste(CharSequence text) {
        if(text == null)
            return;
        synchronized(ui) {
            insert(clean(text.toString()));
            goal = -1;
            follow();
        }
    }

    // ---- the mouse -------------------------------------------------------------------------------

    /** The (line, column) under {@code c}, in this widget's own pixels. */
    private int[] at(Coord c) {
        int l = Utils.clip((c.y - PAD + sy) / lineh, 0, lines.size() - 1);
        if(c.y - PAD + sy < 0)
            l = 0;
        int col = render(lines.get(l)).charat(c.x - PAD + sx);
        return new int[] {l, Utils.clip(col, 0, lines.get(l).length())};
    }

    public boolean mousedown(MouseDownEvent ev) {
        if(ev.propagate(this) || super.mousedown(ev))
            return true;
        if(ev.b != 1)
            return false;
        parent.setfocus(this);
        int[] p = at(ev.c);
        move(p[0], p[1], ui.modshift);
        if(al < 0) {
            al = cl;
            ac = cc;
        }
        goal = -1;
        follow();
        drag = ui.grabmouse(this);
        return true;
    }

    public void mousemove(MouseMoveEvent ev) {
        super.mousemove(ev);
        if(drag != null) {
            int[] p = at(ev.c);
            move(p[0], p[1], true);
            follow();
        }
    }

    public boolean mouseup(MouseUpEvent ev) {
        if((ev.b == 1) && (drag != null)) {
            drag.remove();
            drag = null;
            if(!hassel())
                al = -1;
            return true;
        }
        return super.mouseup(ev);
    }

    public boolean mousewheel(MouseWheelEvent ev) {
        if(ev.propagate(this) || super.mousewheel(ev))
            return true;
        scrollval(sy + (int)Math.round(ev.s * lineh * 3));
        return true;
    }

    // ---- the draw --------------------------------------------------------------------------------

    /** One line, rendered: from the cache when it is there. */
    private Text.Line render(String line) {
        Text.Line t = cache.get(line);
        if(t == null) {
            Fonts.enterTyped("textentry");
            try {
                t = fnd.render(line, fgcol);
            } finally {
                Fonts.exit();
            }
            cache.put(line, t);
        }
        return t;
    }

    private void dropcache() {
        for(Text.Line t : cache.values())
            t.dispose();
        cache.clear();
    }

    public void draw(GOut g) {
        if(fontgen != Fonts.gen()) {
            dropcache();
            fontgen = Fonts.gen();
            Fonts.enterTyped("textentry");
            try {
                lineh = Math.max(1, fnd.height());
            } finally {
                Fonts.exit();
            }
        }
        clampscroll();
        g.chcolor(bgcol);
        g.frect(Coord.z, sz);
        g.chcolor();
        GOut tg = g.reclip(Coord.z, Coord.of(sz.x - sb.sz.x, sz.y));
        Map<String, Text.Line> used = new HashMap<String, Text.Line>();
        int[] s = hassel() ? sel() : null;
        int first = Math.max(0, (sy - PAD) / lineh), last = Math.min(lines.size() - 1, (sy + sz.y) / lineh);
        int space = render(" ").advance(1);
        for(int i = first; i <= last; i++) {
            String line = lines.get(i);
            Text.Line t = render(line);
            used.put(line, t);
            int y = PAD + (i * lineh) - sy;
            if((s != null) && (i >= s[0]) && (i <= s[2])) {
                int x0 = (i == s[0]) ? t.advance(s[1]) : 0;
                int x1 = (i == s[2]) ? t.advance(s[3]) : t.advance(line.length()) + space;
                tg.chcolor(TextEntry.selcol);
                tg.frect2(Coord.of(PAD + x0 - sx, y), Coord.of(PAD + x1 - sx, y + lineh));
                tg.chcolor();
            }
            tg.image(t.tex(), Coord.of(PAD - sx, y));
            if((i == cl) && hasfocus && (((Utils.rtime() - mtime) % 1.0) < 0.5)) {
                tg.chcolor(fgcol);
                tg.frect(Coord.of(PAD + t.advance(cc) - sx, y), Coord.of(UI.scale(1), lineh));
                tg.chcolor();
            }
        }
        used.put(" ", render(" "));
        for(Map.Entry<String, Text.Line> e : cache.entrySet()) {
            if(!used.containsKey(e.getKey()))
                e.getValue().dispose();
        }
        cache = used;
        super.draw(g);
    }

    public void gotfocus() {
        mtime = Utils.rtime();
        super.gotfocus();
    }

    public void dispose() {
        dropcache();
        super.dispose();
    }
}
