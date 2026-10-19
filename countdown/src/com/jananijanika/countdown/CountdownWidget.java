package com.jananijanika.countdown;

import android.app.PendingIntent;
import android.appwidget.AppWidgetManager;
import android.appwidget.AppWidgetProvider;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.widget.RemoteViews;

/** The home-screen widget: the days left until 21 November. Refreshes every half hour, and when the clock changes. */
public class CountdownWidget extends AppWidgetProvider {
    @Override
    public void onUpdate(Context context, AppWidgetManager manager, int[] ids) {
        for (int id : ids)
            manager.updateAppWidget(id, views(context));
    }

    @Override
    public void onReceive(Context context, Intent intent) {
        super.onReceive(context, intent);
        String a = intent.getAction();
        if (Intent.ACTION_TIME_CHANGED.equals(a) || Intent.ACTION_TIMEZONE_CHANGED.equals(a))
            refreshAll(context);
    }

    static void refreshAll(Context context) {
        AppWidgetManager m = AppWidgetManager.getInstance(context);
        int[] ids = m.getAppWidgetIds(new ComponentName(context, CountdownWidget.class));
        for (int id : ids)
            m.updateAppWidget(id, views(context));
    }

    static RemoteViews views(Context context) {
        int days = Countdown.daysLeft();
        RemoteViews v = new RemoteViews(context.getPackageName(), R.layout.widget);
        if (days == 0) {
            v.setTextViewText(R.id.days, "🎂");
            v.setTextViewText(R.id.label, "Happy Birthday!");
        } else {
            v.setTextViewText(R.id.days, String.valueOf(days));
            v.setTextViewText(R.id.label, Countdown.label(days));
        }
        // tapping the widget opens the app
        Intent open = new Intent(context, MainActivity.class);
        v.setOnClickPendingIntent(R.id.root, PendingIntent.getActivity(context, 0, open,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE));
        return v;
    }
}
