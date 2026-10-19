package com.jananijanika.countdown;

import android.app.Activity;
import android.appwidget.AppWidgetManager;
import android.content.ComponentName;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.view.Gravity;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/** The app's one screen: the big countdown, and a button that puts the widget on the home screen. */
public class MainActivity extends Activity {
    @Override
    protected void onCreate(Bundle saved) {
        super.onCreate(saved);
        getWindow().setStatusBarColor(Color.parseColor("#0A0A1E"));
        getWindow().setNavigationBarColor(Color.parseColor("#0A0A1E"));

        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setGravity(Gravity.CENTER);
        col.setPadding(dp(32), dp(32), dp(32), dp(32));
        GradientDrawable bg = new GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM,
                new int[] { Color.parseColor("#1B1638"), Color.parseColor("#0A0A1E") });
        col.setBackground(bg);

        int days = Countdown.daysLeft();
        col.addView(text("✦  Janani & Janika  ✦", 22, "#F4D58D", false));
        TextView big = text(days == 0 ? "🎂" : String.valueOf(days), 120, "#FFF6E3", true);
        big.setShadowLayer(40, 0, 0, Color.parseColor("#AAE8B04A"));
        col.addView(big);
        col.addView(text(Countdown.label(days), 24, "#E8DCC4", false));
        TextView date = text("21 November", 16, "#B89A5A", false);
        date.setLetterSpacing(0.15f);
        date.setPadding(0, dp(8), 0, dp(40));
        col.addView(date);

        Button add = new Button(this);
        add.setText("Add the widget to my home screen");
        add.setAllCaps(false);
        add.setTextColor(Color.parseColor("#1B1638"));
        GradientDrawable gold = new GradientDrawable();
        gold.setColor(Color.parseColor("#E8C77A"));
        gold.setCornerRadius(dp(28));
        add.setBackground(gold);
        add.setPadding(dp(24), dp(14), dp(24), dp(14));
        add.setOnClickListener(b -> pinWidget());
        col.addView(add);

        TextView help = text("Or: long-press an empty spot on your home screen → Widgets → Birthday Countdown", 13, "#8C86A8", false);
        help.setPadding(0, dp(20), 0, 0);
        col.addView(help);
        setContentView(col);
        CountdownWidget.refreshAll(this);
    }

    void pinWidget() {
        if (Build.VERSION.SDK_INT < 26)
            return;
        AppWidgetManager m = getSystemService(AppWidgetManager.class);
        if (m != null && m.isRequestPinAppWidgetSupported())
            m.requestPinAppWidget(new ComponentName(this, CountdownWidget.class), null, null);
    }

    TextView text(String s, int sp, String color, boolean bold) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextSize(sp);
        t.setTextColor(Color.parseColor(color));
        t.setTypeface(Typeface.create(Typeface.SERIF, bold ? Typeface.BOLD : Typeface.NORMAL));
        t.setGravity(Gravity.CENTER);
        return t;
    }

    int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}
