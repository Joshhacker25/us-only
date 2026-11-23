# Love Widget — setup note (Part C)

The native widget code lives in:

- `app/src/main/kotlin/com/onlyus/app/widget/LoveWidgetProvider.kt`
- `app/src/main/res/layout/widget_love_small.xml` (narrow: nickname + days)
- `app/src/main/res/layout/widget_love_medium.xml` (wide: + note + last heart)
- `app/src/main/res/drawable/widget_background.xml` (rounded background)
- `app/src/main/res/xml/love_widget_info.xml` (`updatePeriodMillis` 0 — no polling)
- `app/src/main/res/values/widget_colors.xml` (Midnight Purple palette)

The widget reads its data from SharedPreferences file **`only_us_widget`**
— it never talks to Firestore. The Flutter side
(`lib/features/love_widget/data/widget_preferences_service.dart`) sends
preferences over the MethodChannel `com.onlyus.app/widget`
(method `updateWidget`, arguments: `showNickname`, `showDays`,
`showNote`, `showLastHeart`, `privacyMode`, `nickname`, `sweetNote`,
`anniversary` (ISO-8601, optional), `lastHeart` (ISO-8601, optional)).

## 1. AndroidManifest.xml entries (Part A owns the manifest — DO NOT edit it from Part C)

Add inside `<application>`:

```xml
<receiver
    android:name=".widget.LoveWidgetProvider"
    android:exported="false"
    android:label="Only Us Love">
    <intent-filter>
        <action android:name="android.appwidget.action.APPWIDGET_UPDATE" />
    </intent-filter>
    <meta-data
        android:name="android.appwidget.provider"
        android:resource="@xml/love_widget_info" />
</receiver>

<!-- Re-apply the widget after a reboot. -->
<receiver
    android:name=".widget.LoveWidgetProvider"
    android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
    </intent-filter>
</receiver>
```

And at manifest level (outside `<application>`):

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Note: a single `<receiver>` can hold both intent-filters; they are
shown separately here for clarity.

## 2. MainActivity MethodChannel wiring (Part A owns MainActivity)

In `MainActivity.configureFlutterEngine`, add:

```kotlin
MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.onlyus.app/widget")
    .setMethodCallHandler { call, result ->
        if (call.method == "updateWidget") {
            // 1. Persist the args into SharedPreferences "only_us_widget"
            //    so LoveWidgetProvider can read them.
            val prefs = getSharedPreferences("only_us_widget", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            (call.argument<Boolean>("showNickname"))?.let { editor.putBoolean("showNickname", it) }
            (call.argument<Boolean>("showDays"))?.let { editor.putBoolean("showDays", it) }
            (call.argument<Boolean>("showNote"))?.let { editor.putBoolean("showNote", it) }
            (call.argument<Boolean>("showLastHeart"))?.let { editor.putBoolean("showLastHeart", it) }
            (call.argument<Boolean>("privacyMode"))?.let { editor.putBoolean("privacyMode", it) }
            (call.argument<String>("nickname"))?.let { editor.putString("nickname", it) }
            (call.argument<String>("sweetNote"))?.let { editor.putString("sweetNote", it) }
            (call.argument<String>("anniversary"))?.let { editor.putString("anniversary", it) }
            (call.argument<String>("lastHeart"))?.let { editor.putString("lastHeart", it) }
            editor.apply()
            // 2. Tell the widget to redraw now.
            sendBroadcast(Intent("com.onlyus.app.widget.ACTION_UPDATE_WIDGET"))
            result.success(null)
        } else {
            result.notImplemented()
        }
    }
```

## 3. Behaviour notes

- Privacy mode ON (default): the sweet note and last-heart lines are
  hidden on the widget. The widget cannot confirm the phone is
  unlocked, so it errs on the side of hiding.
- Days counter counts from the `anniversary` date (days together).
- Tapping the widget opens `MainActivity`.
- The widget was NOT tested on a device in this task (no device / emulator
  available here) — verify on a real phone after Part A wires the manifest
  and MainActivity entries above.
