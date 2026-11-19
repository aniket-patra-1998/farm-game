package com.farmgame.notices;

import android.app.Activity;
import android.app.AlarmManager;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;

/**
 * Phone notifications for the farm game (scripts/systems/phone_notices.gd plans them): the game, going to the
 * background, schedules a few with the phone's alarm clock; NoticeReceiver shows each when its time comes, even
 * with the game closed. Local only: no server, no network.
 */
public class FarmNotices extends GodotPlugin {
    static final String EXTRA_ID = "id";
    static final String EXTRA_TITLE = "title";
    static final String EXTRA_TEXT = "text";
    private static final int MOST = 8;           // the ids a plan can use (PhoneNotices plans at most a few)
    private static final int ASK_CODE = 4401;    // the permission request's code
    private static final String PERMISSION = "android.permission.POST_NOTIFICATIONS";

    public FarmNotices(Godot godot) {
        super(godot);
    }

    @Override
    public String getPluginName() {
        return "FarmNotices";
    }

    private Context context() {
        Activity a = getActivity();
        return a != null ? a.getApplicationContext() : null;
    }

    private PendingIntent pending(Context c, int id, String title, String text) {
        Intent i = new Intent(c, NoticeReceiver.class);
        i.putExtra(EXTRA_ID, id);
        i.putExtra(EXTRA_TITLE, title);
        i.putExtra(EXTRA_TEXT, text);
        return PendingIntent.getBroadcast(c, id, i,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    /** Shows `text` under `title` in `seconds` (notification `id`, 0 to MOST - 1, replaces one with that id). */
    @UsedByGodot
    public void schedule(int id, String title, String text, int seconds) {
        Context c = context();
        if (c == null || id < 0 || id >= MOST) {
            return;
        }
        AlarmManager alarms = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        if (alarms == null) {
            return;
        }
        long at = System.currentTimeMillis() + Math.max(1, seconds) * 1000L;
        // Inexact on purpose (no exact-alarm permission): a few minutes late is fine for "your crops are ready".
        alarms.set(AlarmManager.RTC_WAKEUP, at, pending(c, id, title, text));
    }

    /** Takes back every planned notification and clears the shown ones (the player is back in the game). */
    @UsedByGodot
    public void cancelAll() {
        Context c = context();
        if (c == null) {
            return;
        }
        AlarmManager alarms = (AlarmManager) c.getSystemService(Context.ALARM_SERVICE);
        for (int id = 0; id < MOST; id++) {
            if (alarms != null) {
                alarms.cancel(pending(c, id, "", ""));
            }
        }
        NotificationManager shown = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (shown != null) {
            shown.cancelAll();
        }
    }

    /** Android 13 and later: asks the player once whether the game may notify (Android stops asking after no). */
    @UsedByGodot
    public void askPermission() {
        Activity a = getActivity();
        if (a == null || Build.VERSION.SDK_INT < 33) {
            return;
        }
        if (a.checkSelfPermission(PERMISSION) != PackageManager.PERMISSION_GRANTED) {
            a.requestPermissions(new String[] {PERMISSION}, ASK_CODE);
        }
    }
}
