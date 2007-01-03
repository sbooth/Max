/**
 * jnotify.java
 *
 * Version:
 * $Id:$
 * 
 * Revisions:
 * $Log:$
 *
 */

import com.growl.Growl;

/**
 * The main run class in our example Java-Growl example.
 *
 * @author Karl Adam
 */
public class jnotify {

    /**
     * Main method.
     *
     * @param args - The array of strings fed on the command line to jnotify.
     */
    public static void main (String [] args) {
		String [] allMyNotes = { "Jnotify Notification" };
		Growl theGrowl = new Growl("jnotify", allMyNotes, allMyNotes);

		theGrowl.register();

		try {
			theGrowl.notifyGrowlOf("Jnotify Notification", "Java sucks", 
					"It does doesn't it, but now it has the honor"
				    	+ " of talking to growl");
		} catch (Exception e) {
			System.err.println(e);
		}
    }
}
