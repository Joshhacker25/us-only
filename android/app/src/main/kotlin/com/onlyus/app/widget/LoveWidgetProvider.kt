package com.onlyus.app.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Bundle
import android.widget.RemoteViews
import com.onlyus.app.R
import java.time.LocalDate
import java.time.format.DateTimeParseException
import java.time.temporal.ChronoUnit

/**
 * Home-screen Love widget for Only Us.
 *
 * Static RemoteViews widget (no RemoteViewsService / collection needed):
 * shows the partner nickname, days together, an optional sweet note and
 * the last heart received.
 *
 * Data source: SharedPreferences file "only_us_widget", written by
 * MainActivity from the Flutter side's MethodChannel call
 * ("com.onlyus.app/widget", method "updateWidget"). The widget never
 * talks to Firestore or the network itself.
 *
 * Keys read (all optional — every missing value hides that row):
 *   showNickname  Boolean  show the partner nickname
 *   showDays      Boolean  show the days-together counter
 *   showNote      Boolean  show the sweet note
 *   showLastHeart Boolean  show the last-heart line
 *   privacyMode   Boolean  when true, the note and last-heart line are
 *                          hidden (the widget cannot confirm the phone
 *                          is unlocked, so it errs on the side of hiding)
 *   nickname      String   partner nickname
 *   sweetNote     String   sweet note
 *   anniversary   String   ISO-8601 date the days counter counts from
 *   lastHeart     String   ISO-8601 timestamp of the last heart
 *
 * Updates:
 *   - onUpdate(): when the widget is added / resized (updatePeriodMillis
 *     is 0 — no polling; updates are pushed).
 *   - ACTION_UPDATE_WIDGET broadcast ("com.onlyus.app.widget.ACTION_UPDATE_WIDGET"):
 *     sent by MainActivity whenever the Flutter side changes the
 *     preferences or a heart arrives.
 *   - BOOT_COMPLETED: re-applies the last saved values after a reboot
 *     (receiver entry lives in AndroidManifest.xml — see
 *     android/WIDGET_SETUP_NOTE.md; Part A owns the manifest).
 *
 * Tap: opens MainActivity (the app) via an immutable PendingIntent.
 */
class LoveWidgetProvider : AppWidgetProvider() {

    companion object {
        const val ACTION_UPDATE_WIDGET = "com.onlyus.app.widget.ACTION_UPDATE_WIDGET"
        const val PREFS_NAME = "only_us_widget"
        private const val MAIN_ACTIVITY_CLASS = "com.onlyus.app.MainActivity"
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        val action = intent.action
        if (action == ACTION_UPDATE_WIDGET ||
            action == Intent.ACTION_BOOT_COMPLETED
        ) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, LoveWidgetProvider::class.java)
            )
            onUpdate(context, manager, ids)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        updateWidget(context, appWidgetManager, appWidgetId)
    }

    private fun updateWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int
    ) {
        val prefs: SharedPreferences =
            context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val showNickname = prefs.getBoolean("showNickname", true)
        val showDays = prefs.getBoolean("showDays", true)
        val showNote = prefs.getBoolean("showNote", true)
        val showLastHeart = prefs.getBoolean("showLastHeart", true)
        val privacyMode = prefs.getBoolean("privacyMode", true)
        val nickname = prefs.getString("nickname", "") ?: ""
        val sweetNote = prefs.getString("sweetNote", "") ?: ""
        val anniversary = prefs.getString("anniversary", null)
        val lastHeart = prefs.getString("lastHeart", null)

        // Small layout for narrow widgets, medium layout otherwise.
        val options = appWidgetManager.getAppWidgetOptions(appWidgetId)
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val useSmallLayout = minWidth in 1 until 250
        val layoutId = if (useSmallLayout) R.layout.widget_love_small
                       else R.layout.widget_love_medium

        val views = RemoteViews(context.packageName, layoutId)

        // Tap anywhere on the widget opens the app.
        val openApp = Intent().setClassName(context, MAIN_ACTIVITY_CLASS)
        openApp.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        val pending = PendingIntent.getActivity(
            context,
            appWidgetId,
            openApp,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, pending)

        // Nickname.
        if (showNickname && nickname.isNotBlank()) {
            views.setTextViewText(R.id.widget_nickname, nickname)
            views.setViewVisibility(R.id.widget_nickname, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_nickname, android.view.View.GONE)
        }

        // Days together.
        val days = daysSince(anniversary)
        if (showDays && days != null) {
            val text = if (days == 1) "1 day together 💕" else "$days days together 💕"
            views.setTextViewText(R.id.widget_days, text)
            views.setViewVisibility(R.id.widget_days, android.view.View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_days, android.view.View.GONE)
        }

        // Sweet note + last heart only exist on the medium layout and
        // are hidden whenever privacy mode is on.
        if (!useSmallLayout) {
            if (showNote && !privacyMode && sweetNote.isNotBlank()) {
                views.setTextViewText(R.id.widget_note, sweetNote)
                views.setViewVisibility(R.id.widget_note, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_note, android.view.View.GONE)
            }
            if (showLastHeart && !privacyMode && lastHeart != null) {
                views.setTextViewText(R.id.widget_last_heart, "Last heart: $lastHeart")
                views.setViewVisibility(R.id.widget_last_heart, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_last_heart, android.view.View.GONE)
            }
        }

        appWidgetManager.updateAppWidget(appWidgetId, views)
    }

    /** Days between [anniversaryIso] (ISO-8601) and today, or null. */
    private fun daysSince(anniversaryIso: String?): Long? {
        if (anniversaryIso.isNullOrBlank()) return null
        return try {
            // Accept a full timestamp or a plain date; count from the date part.
            val datePart = anniversaryIso.substringBefore('T')
            val start = LocalDate.parse(datePart)
            ChronoUnit.DAYS.between(start, LocalDate.now()).coerceAtLeast(0)
        } catch (_: DateTimeParseException) {
            null
        } catch (_: StringIndexOutOfBoundsException) {
            null
        }
    }
}
