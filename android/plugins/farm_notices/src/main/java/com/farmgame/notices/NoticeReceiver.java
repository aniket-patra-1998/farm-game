package com.farmgame.notices;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;

/** Shows one planned notification when its alarm comes; a tap on it opens the game. */
public class NoticeReceiver extends BroadcastReceiver {
    private static final String CHANNEL = "farm";

    @Override
    public void onReceive(Context c, Intent intent) {
        NotificationManager shown = (NotificationManager) c.getSystemService(Context.NOTIFICATION_SERVICE);
        if (shown == null) {
            return;
        }
        if (Build.VERSION.SDK_INT >= 26) {
            NotificationChannel channel = new NotificationChannel(CHANNEL, "Farm", NotificationManager.IMPORTANCE_DEFAULT);
            channel.setDescription("Crops ready, animals ready, the daily gift");
            shown.createNotificationChannel(channel);
        }
        Intent open = c.getPackageManager().getLaunchIntentForPackage(c.getPackageName());
        PendingIntent tap = open == null ? null
                : PendingIntent.getActivity(c, 0, open, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        Notification.Builder b = Build.VERSION.SDK_INT >= 26
                ? new Notification.Builder(c, CHANNEL)
                : new Notification.Builder(c);
        b.setSmallIcon(c.getApplicationInfo().icon)
                .setContentTitle(intent.getStringExtra(FarmNotices.EXTRA_TITLE))
                .setContentText(intent.getStringExtra(FarmNotices.EXTRA_TEXT))
                .setAutoCancel(true);
        if (tap != null) {
            b.setContentIntent(tap);
        }
        try {
            shown.notify(intent.getIntExtra(FarmNotices.EXTRA_ID, 0), b.build());
        } catch (SecurityException e) {
            // The player said no to notifications: nothing is shown.
        }
    }
}
