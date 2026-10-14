package io.brodgar.addon;

import haven.GSprite;
import haven.GameUI;
import haven.ItemInfo;
import haven.KeyBinding;
import haven.KeyMatch;
import haven.MenuGrid;
import haven.Resource;
import haven.RichText;
import haven.Tex;
import haven.UI;

import java.util.ArrayList;
import java.util.List;

/**
 * <b>A macro on the action bar</b> (174): a {@link MenuGrid.Pagina} over the stand-in {@link AddonPagina} uses,
 * so a slot holds it through {@link BeltHold} exactly as it holds an addon's entry, and
 * {@code GameUI.PagBeltSlot} draws and fires it through {@link #button()} with nothing in {@code GameUI}
 * changed.
 *
 * <p><b>It is never in {@code paginae}</b>: a macro stands on its page and on the bar, never in the action
 * menu. It carries only the macro's id; the name and the icon are read from {@link Macros} on every call, so a
 * rename or an edit on the page shows in every slot it stands in.
 */
public final class MacroPagina extends MenuGrid.Pagina {
    /** The id of the macro this stands for. */
    final int macro;
    /** The identity on the bar, {@code macro/<id>}. */
    final String id;

    private Button button;

    MacroPagina(MenuGrid scm, int macro) {
        super(scm, Macros.ENTRY + macro, AddonPagina.standin());
        this.macro = macro;
        this.id = Macros.ENTRY + macro;
    }

    /**
     * A macro to drag from the Macros page onto {@code ui}'s action bar, or {@code null} where that session has
     * no action menu (the login screen): nothing then drags.
     */
    public static MacroPagina of(UI ui, int macro) {
        GameUI g = AddonManager.gui(ui);
        if((g == null) || (g.menu == null))
            return null;
        return new MacroPagina(g.menu, macro);
    }

    /** The macro of {@code entry} ({@code macro/<id>}), or {@code -1} for anything else. */
    static int idOf(String entry) {
        if((entry == null) || !entry.startsWith(Macros.ENTRY))
            return -1;
        try {
            return Integer.parseInt(entry.substring(Macros.ENTRY.length()));
        } catch(NumberFormatException e) {
            return -1;
        }
    }

    /** The drawn button, minted once — {@code Pagina.button} is private, so the subclass caches its own. */
    public MenuGrid.PagButton button() {
        if(button == null)
            button = new Button(this);
        return button;
    }

    /** Under nothing: it stands in no screen of the menu. */
    public MenuGrid.Pagina parent() {
        return null;
    }

    /** The macro's name now, or the identity once it is deleted. */
    String name() {
        Macro m = Macros.get(macro);
        return (m == null) ? id : m.name;
    }

    public String toString() {
        return "MacroPagina(" + id + ")";
    }

    /**
     * The drawn half. Every override reads {@code pag} or a constant: {@code PagButton(Pagina)} calls the
     * virtual {@code binding()} before a subclass field exists.
     */
    static final class Button extends MenuGrid.PagButton {
        /** One binding for every macro, in no registry: a macro adds no row to the keybind panel. */
        private static final KeyBinding NONE = KeyBinding.unlisted("scm/" + Macros.ENTRY, KeyMatch.nil);

        private GSprite spr;
        private String sprfor;

        Button(MacroPagina pag) {
            super(pag);
        }

        private MacroPagina pag() {
            return (MacroPagina)pag;
        }

        /** The name, quoted: what a tip paints it into is {@code RichText}. */
        public String name() {
            return RichText.Parser.quote(pag().name());
        }

        public String sortkey() {
            return pag().name();
        }

        public MenuGrid.Pagina parent() {
            return null;
        }

        public KeyBinding binding() {
            return NONE;
        }

        public KeyMatch hotkey() {
            return KeyMatch.nil;
        }

        /** The macro's icon fitted to the cell, rebuilt when the icon changes. Throws {@code Loading} while it loads. */
        public GSprite spr() {
            Macro m = Macros.get(pag().macro);
            String icon = (m == null) ? Macros.ICON : m.icon;
            if((spr == null) || !icon.equals(sprfor)) {
                Tex tex = Resource.local().load(icon).get().flayer(Resource.imgc).tex();
                spr = new AddonPagina.Icon(this, tex);
                sprfor = icon;
            }
            return spr;
        }

        /** A press — the slot's key, a click on it, {@code slot:use()}. Nothing is sent: the macro runs. */
        public void use(MenuGrid.Interaction iact) {
            AddonManager.runMacro(pag().macro);
        }

        /** Nothing under the name. A fresh list every call: {@code rendertt} deletes from the one it is handed. */
        public List<ItemInfo> info() {
            return new ArrayList<ItemInfo>();
        }
    }
}
