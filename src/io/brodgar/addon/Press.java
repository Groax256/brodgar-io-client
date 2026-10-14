package io.brodgar.addon;

/**
 * <b>The player's press on one addon</b> (175.3) — the moment a macro may run through {@code slot:use()}. A
 * macro runs in the console's Lua, unsandboxed, so an addon that could run one whenever it liked would hold
 * {@code console.run} without its consent line. What it holds instead is the player's own act: while the
 * engine is handing one addon a press on something of its own, that addon may run one macro, synchronously.
 *
 * <p><b>The doors that open one</b>, each wrapping its existing fire in {@link #open}/{@link #close}: a
 * {@code MouseDown} on a widget the addon built ({@link WidgetSubs}), a {@code Pressed} of its control
 * ({@link Controls#fire}), its hotkey going down and its console command ({@link HookApi}), and its menu entry
 * pressed from the grid or the bar ({@link AddonPagina#fire}).
 *
 * <p><b>Opened only from the engine.</b> {@link #open} does nothing while {@link AddonManager#current} names
 * an addon: Lua is on the stack, so whatever is firing was caused by code, not by the player. That one test is
 * what keeps {@code pag:use()}, {@code slot:use()} on a held entry, {@code hafen.console():run} and
 * {@code ev:resend()} from opening one, since each fires through the same doors.
 *
 * <p><b>Per thread.</b> A press is the synchronous handling of one input, so it lives exactly as long as the
 * fire on the thread that took the input; a timer set inside it runs later, on a closed press.
 */
final class Press {
    /** One open press: whose it is, and whether it has already run its macro. */
    static final class State {
        final Addon owner;
        boolean spent;

        State(Addon owner) {
            this.owner = owner;
        }
    }

    private static final ThreadLocal<State> current = new ThreadLocal<State>();

    private Press() {
    }

    /**
     * Open a press for {@code owner} — unless Lua is already running on this thread, in which case nothing
     * changes. Returns the state to hand {@link #close}, in a {@code finally}.
     */
    static State open(Addon owner) {
        State prev = current.get();
        if((owner != null) && (AddonManager.current() == null))
            current.set(new State(owner));
        return prev;
    }

    /** {@link #open}'s other half: put back the press that stood before it, or none. */
    static void close(State prev) {
        if(prev == null)
            current.remove();
        else
            current.set(prev);
    }

    /** Take the press for one macro: {@code true} once per press, and only for its owner. */
    static boolean take(Addon owner) {
        State s = current.get();
        if((s == null) || (s.owner != owner) || s.spent)
            return false;
        s.spent = true;
        return true;
    }

    /** Is {@code owner} inside its own press, already spent? What tells the second refusal from the first. */
    static boolean spent(Addon owner) {
        State s = current.get();
        return (s != null) && (s.owner == owner) && s.spent;
    }
}
