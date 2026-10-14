package io.brodgar.addon;

/**
 * <b>One macro</b> the player keeps ({@link Macros}): a name, an icon and a body of Lua. An immutable value — a
 * save makes a new one, so a reader holding one never sees it half-written. {@link #id} is the row's, stable
 * across a rename, and what an action-bar slot holds it by ({@link Macros#ENTRY}).
 *
 * <p><b>Two identities</b> (175). {@link #id} is the client's: the slot record and {@link MacroPagina} carry it,
 * and it never reaches Lua, because it counts the macros the player has made. {@link #token} is the one an addon
 * is handed, {@code macro/<token>} ({@link Macros#res}): random, and stable for the macro's life.
 */
public final class Macro {
    public final int id;
    /** 32 lowercase hex characters, minted once by {@link Macros#mint}. */
    public final String token;
    public final String name;
    /** A resource name, drawn by its first image layer. Every macro records {@link Macros#ICON} today. */
    public final String icon;
    public final String body;

    public Macro(int id, String token, String name, String icon, String body) {
        this.id = id;
        this.token = token;
        this.name = name;
        this.icon = icon;
        this.body = body;
    }

    public String toString() {
        return "Macro(" + id + ", " + name + ")";
    }
}
