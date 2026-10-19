package com.jananijanika.countdown;

import java.util.Calendar;

/** Days until the twins' birthday (21 November), counted in whole calendar days on the phone's own clock. */
final class Countdown {
    static final int MONTH = Calendar.NOVEMBER, DAY = 21;

    /** 0 on the birthday itself; otherwise the days until the next 21 November. */
    static int daysLeft() {
        Calendar today = Calendar.getInstance();
        clearTime(today);
        Calendar party = (Calendar) today.clone();
        party.set(Calendar.MONTH, MONTH);
        party.set(Calendar.DAY_OF_MONTH, DAY);
        if (party.before(today))
            party.add(Calendar.YEAR, 1);
        long ms = party.getTimeInMillis() - today.getTimeInMillis();
        return (int) Math.round(ms / 86400000.0); // (rounded: a clock change can make a day 23 or 25 hours)
    }

    static String label(int days) {
        return days == 0 ? "Happy Birthday!" : days == 1 ? "day to go · tomorrow!" : "days to go";
    }

    private static void clearTime(Calendar c) {
        c.set(Calendar.HOUR_OF_DAY, 0);
        c.set(Calendar.MINUTE, 0);
        c.set(Calendar.SECOND, 0);
        c.set(Calendar.MILLISECOND, 0);
    }

    private Countdown() {}
}
