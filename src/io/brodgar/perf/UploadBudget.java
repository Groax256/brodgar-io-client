package io.brodgar.perf;

import java.util.concurrent.atomic.AtomicLong;

/**
 * How much new geometry and texture the frame may put on the GPU for ground that is not under the character: the
 * far ground's cells, the remembered ground's merged grids and its click map.
 *
 * <p>Whatever a frame adds to the scene is uploaded by the render thread before that frame is drawn, all of it, and
 * nothing upstream bounds how much that is. Loading the remembered ground lands hundreds of cells and grids a second
 * -- at login, on a zoom that brings finer ground in -- and a frame that took a few megabytes of them spent 10-20 ms
 * of the render thread uploading them, which is the frame rate going from 200 to 40. What is spent from this is a
 * share of each frame instead: what does not fit waits for the next one, where it was in the queue, and the ground
 * comes in over a few more frames at the frame rate it stands at.
 *
 * <p>The share is a TIME on the render thread, {@link #VIEWNS} and {@link #BACKNS} a frame, turned into bytes by
 * what uploading has been costing: the render thread reports how long it spends on the frame's uploads
 * ({@link #rendered}), and that over the bytes spent here is the cost of a byte, kept as a running average. A byte
 * costs very differently by machine and by what it is -- a far cell's texture levels and small buffers cost several
 * times a merged grid's large ones -- and what the live world uploads meanwhile (the ground under the character,
 * objects, the interface) is counted in that time too, so while the world is arriving the remembered ground gives way.
 *
 * <p>Two pools, so what is kept around the view for a turn of the camera never starves what the view shows: the
 * VIEW pool for what is on screen (a grid the view wants whole, a far cell it draws), the BACK pool for the rest.
 * Each is a bucket: a frame adds its share, up to one frame's worth, and a piece may go while the bucket holds
 * anything -- so one larger than a frame's share still goes, and leaves the bucket in debt for as many frames as it
 * was larger, which holds the average to the share at any frame rate. Read and
 * spent on the UI thread only, reset once a frame by {@code UILoop.Frame.run} before the tick that spends it. Nothing
 * that would be a hole on screen waits for it -- the live ground under the character, a grid already drawn whole, a
 * cut handed over between the live and the remembered ground -- and those spend it all the same ({@link #spend}).
 */
public final class UploadBudget {
    /** Render-thread time a frame, each pool. */
    public static final long VIEWNS = 1_000_000, BACKNS = 400_000;
    /** The pools' bounds in bytes, whatever the cost of a byte says. */
    private static final long MINBYTES = 32 * 1024, MAXBYTES = 4 << 20;
    /** What the cost of a byte is re-estimated over: at least this many bytes spent, and this long. */
    private static final long WINBYTES = 512 * 1024, WINNS = 250_000_000;
    /** How many frames' worth a bucket may owe. */
    private static final long DEBT = 8;

    private static final AtomicLong rendns = new AtomicLong();
    /* The cost of a byte in ns, as a running average; the window it is measured over. */
    private static double nsperbyte = 5.0;
    private static long winspent = 0, winstart = System.nanoTime();

    private static long vleft = 0, bleft = 0;

    private UploadBudget() {}

    /** The render thread spent {@code ns} on a frame's uploads. Any thread. */
    public static void rendered(long ns) {
	rendns.addAndGet(ns);
    }

    /** A new frame: each pool's share added, in bytes at what a byte has been costing. */
    public static void frame() {
	long now = System.nanoTime();
	if(((now - winstart) >= WINNS) && (winspent >= WINBYTES)) {
	    double cost = (double)rendns.getAndSet(0) / winspent;
	    nsperbyte = (nsperbyte * 0.5) + (cost * 0.5);
	    winspent = 0;
	    winstart = now;
	} else if((now - winstart) >= (WINNS * 8)) {
	    /* Too little spent to say anything: what the render thread did meanwhile was somebody else's. */
	    rendns.set(0);
	    winspent = 0;
	    winstart = now;
	}
	long vb = bytes(VIEWNS), bb = bytes(BACKNS);
	/* What never waits (spend) may take a bucket further into debt than the pieces that do could pay off soon:
	 * held to DEBT frames' worth, so a burst of those delays the rest by that much at most. */
	vleft = Math.min(Math.max(vleft, -vb * DEBT) + vb, vb);
	bleft = Math.min(Math.max(bleft, -bb * DEBT) + bb, bb);
    }

    private static long bytes(long ns) {
	return(Math.max(MINBYTES, Math.min(MAXBYTES, (long)(ns / Math.max(nsperbyte, 0.01)))));
    }

    /** Whether anything more may be uploaded this frame from the view's pool ({@code view}) or the other one. */
    public static boolean room(boolean view) {
	return(view ? (vleft > 0) : (bleft > 0));
    }

    /** Take {@code bytes} from a pool if it has room: whether the piece may go this frame. */
    public static boolean take(boolean view, long bytes) {
	if(!room(view))
	    return(false);
	spend(view, bytes);
	return(true);
    }

    /** Count {@code bytes} that go this frame whatever the pool says. */
    public static void spend(boolean view, long bytes) {
	winspent += bytes;
	if(view)
	    vleft -= bytes;
	else
	    bleft -= bytes;
    }

    /** What a byte has been costing the render thread, in ns: for the profiler. */
    public static double nsperbyte() {
	return(nsperbyte);
    }
}
