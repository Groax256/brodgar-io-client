package io.brodgar.addon;

/**
 * <b>One macro</b> the player keeps ({@link Macros}): a name, an icon and a body of Lua. An immutable value — a
 * save makes a new one, so a reader holding one never sees it half-written. {@link #id} is the row's, stable
 * across a rename, and what an action-bar slot holds it by ({@link Macros#ENTRY}).
 */
public final class Macro {
    public final int id;
    public final String name;
    /** A resource name, drawn by its first image layer. Every macro records {@link Macros#ICON} today. */
    public final String icon;
    public final String body;

    public Macro(int id, String name, String icon, String body) {
        this.id = id;
        this.name = name;
        this.icon = icon;
        this.body = body;
    }

    public String toString() {
        return "Macro(" + id + ", " + name + ")";
    }
}
