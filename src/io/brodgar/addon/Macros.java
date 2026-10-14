package io.brodgar.addon;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * <b>The player's macros</b> (174): one list for the whole client, every account and character, kept in
 * {@code savedata/client.sqlite} ({@link ClientDb#macros}). Read from the file once, on first use, and held as
 * an immutable snapshot swapped whole on every write, so the draw thread reads it with no lock. Every write
 * goes to the file first and then to the snapshot; {@link #gen} moves with each, and is what a page showing
 * the list polls.
 *
 * <p><b>Unavailable file.</b> The list is what the file held (nothing, when it could not be read), and writes
 * are kept in memory for the session: a macro added then takes the next id after the highest held.
 */
public final class Macros {
    /**
     * The icon every macro records: a local resource, the client's wrench cursor — 30&times;31, so it stands
     * whole in an action-bar cell. The game menu's own buttons are not one: each is a whole HUD-sized canvas
     * with the button in a corner of it.
     */
    public static final String ICON = "gfx/hud/curs/wrench";
    /** The longest body a macro holds, in characters. */
    public static final int MAX_BODY = 65536;
    /** The prefix of a macro's identity on the action bar, {@code macro/<id>}. */
    public static final String ENTRY = "macro/";
    /** The name {@link #create} gives a new macro. */
    public static final String NEW_NAME = "New macro";

    private static volatile List<Macro> list = null;
    private static volatile int gen = 0;

    private Macros() {}

    /** Every macro, by id. The same list until the next write. Never {@code null}. */
    public static List<Macro> all() {
        List<Macro> l = list;
        if(l == null)
            l = load();
        return l;
    }

    private static synchronized List<Macro> load() {
        if(list == null) {
            List<Macro> read = ClientDb.macros();
            list = Collections.unmodifiableList((read == null) ? new ArrayList<Macro>() : read);
        }
        return list;
    }

    /** The macro of {@code id} as the list holds it now, or {@code null}: it was deleted, or never was. */
    public static Macro get(int id) {
        for(Macro m : all()) {
            if(m.id == id)
                return m;
        }
        return null;
    }

    /** Moves with every write to the list. */
    public static int gen() {
        return gen;
    }

    /** A new macro, {@link #NEW_NAME} with {@link #ICON} and an empty body, at the end of the list. */
    public static synchronized Macro create() {
        List<Macro> cur = all();
        int id = ClientDb.macroAdd(NEW_NAME, ICON, "");
        if(id < 0) {
            id = 1;
            for(Macro m : cur)
                id = Math.max(id, m.id + 1);
        }
        Macro m = new Macro(id, NEW_NAME, ICON, "");
        List<Macro> next = new ArrayList<Macro>(cur);
        next.add(m);
        swap(next);
        return m;
    }

    /**
     * Store {@code name} and {@code body} on the macro of {@code id}; answers it as now held, or {@code null}
     * where there is no such macro. Nothing is written when both are what it already holds.
     *
     * @throws IllegalArgumentException an empty name, or a body longer than {@link #MAX_BODY}
     */
    public static synchronized Macro save(int id, String name, String body) {
        if((name == null) || name.trim().isEmpty())
            throw new IllegalArgumentException("a macro needs a name");
        if(body == null)
            body = "";
        if(body.length() > MAX_BODY)
            throw new IllegalArgumentException("a macro's body is at most " + MAX_BODY + " characters");
        name = name.trim();
        List<Macro> cur = all();
        for(int i = 0; i < cur.size(); i++) {
            Macro m = cur.get(i);
            if(m.id != id)
                continue;
            if(m.name.equals(name) && m.body.equals(body))
                return m;
            ClientDb.macroSave(id, name, body);
            Macro saved = new Macro(id, name, m.icon, body);
            List<Macro> next = new ArrayList<Macro>(cur);
            next.set(i, saved);
            swap(next);
            return saved;
        }
        return null;
    }

    /** Delete the macro of {@code id}, and every action-bar slot held for it on every character. */
    public static synchronized void delete(int id) {
        List<Macro> next = new ArrayList<Macro>(all());
        boolean had = false;
        for(int i = 0; i < next.size(); i++) {
            if(next.get(i).id == id) {
                next.remove(i);
                had = true;
                break;
            }
        }
        if(!had)
            return;
        ClientDb.macroDelete(id);
        swap(next);
    }

    private static void swap(List<Macro> next) {
        list = Collections.unmodifiableList(next);
        gen++;
    }
}
