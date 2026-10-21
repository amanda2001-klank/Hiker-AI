package com.example.app_venture.watch

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService
import org.json.JSONObject

class Component3AiAlertReceiver : WearableListenerService() {

    companion object {
        private const val TAG = "Watch6AiAlert"
        private const val PATH = "/venture_hike/ai_recommendation"
        private const val SESSION_PATH = "/venture_hike/ai_session"
        private const val SESSION_PREFS = "component3_watch_session_v300"
        private const val CHANNEL_ID = "component3_experimental_alerts"
        private const val COOLDOWN_MS = 120000L
        private const val MAX_AGE_MS = 120000L
    }

    private fun showControlledTestNotification(json: JSONObject) {
        val timestamp = json.optLong("timestamp_ms", 0L)
        val now = System.currentTimeMillis()
        val age = now - timestamp
        val id = json.optString("event_id")
        if (id.isBlank() || id.length > 160 || timestamp <= 0L ||
            age < -30000L || age > 60000L) {
            Log.w(TAG, "TEST_ALERT_REJECTED_STALE_OR_INVALID")
            return
        }
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "TEST_ALERT_PERMISSION_MISSING")
            return
        }
        val prefs = getSharedPreferences("component3_watch_test_alerts", MODE_PRIVATE)
        if (prefs.getString("last_event", "") == id) {
            Log.i(TAG, "TEST_ALERT_DUPLICATE")
            return
        }
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val testChannelId = "component3_notification_delivery_test_v1"
        val channel = NotificationChannel(
            testChannelId, "Hiking AI Test Alerts", NotificationManager.IMPORTANCE_HIGH
        )
        channel.enableVibration(true)
        channel.vibrationPattern = longArrayOf(0L, 300L, 180L, 300L)
        manager.createNotificationChannel(channel)
        val synthetic = json.optString("source") == "synthetic_backend_test"
        val indicator = json.optString("indicator")
        val safeIndicators = setOf("fatigue_related", "physical_strain_related", "heat_exposure_related")
        val rawAdvice = json.optString("message")
        if (synthetic && (indicator !in safeIndicators || rawAdvice.isBlank() || rawAdvice.length > 240)) {
            Log.w(TAG, "SYNTHETIC_TEST_REJECTED_INVALID_PAYLOAD")
            return
        }
        val testHeading = if (synthetic) "TEST AI RESULT - Not real risk" else "TEST ALERT ONLY - Hiking AI"
        val testDescription = if (synthetic) "${indicator.replace('_', ' ')}: $rawAdvice" else "Phone-to-Watch notification test. No real risk detected."
        val testDetails = if (synthetic) "SYNTHETIC BACKEND TEST ONLY. $testDescription Not a real hiking measurement or medical diagnosis." else "TEST ALERT ONLY. Checking notification and vibration delivery. This is not an AI risk prediction or medical warning."
        val notification = Notification.Builder(this, testChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(testHeading)
            .setContentText(testDescription)
            .setStyle(Notification.BigTextStyle().bigText(testDetails))
            .setAutoCancel(true)
            .build()
        manager.notify(28001, notification)
        prefs.edit().putString("last_event", id).apply()
        Log.i(TAG, "TEST_ALERT_NOTIFICATION_POSTED event=" + id)
    }
    private fun handleSessionControl(event: MessageEvent) {
        try {
            if (event.data.size > 2048) return
            val json = JSONObject(String(event.data, Charsets.UTF_8))
            if (json.optInt("version", -1) != 1 ||
                json.optString("type") != "HIKE_SESSION_CONTROL") return
            val command = json.optString("command")
            val id = json.optString("session_id")
            val issued = json.optLong("issued_ms", 0L)
            val now = System.currentTimeMillis()
            if (command !in setOf("START", "STOP") ||
                id.isBlank() || id.length > 64 ||
                !id.all { it.isDigit() } ||
                issued <= 0L || now - issued > 120000L || issued - now > 30000L) {
                Log.w(TAG, "SESSION_CONTROL_REJECTED_INVALID")
                return
            }
            val prefs = getSharedPreferences(SESSION_PREFS, MODE_PRIVATE)
            val previousIssued = prefs.getLong("last_issued_ms", 0L)
            val previousCommand = prefs.getString("last_command", "") ?: ""
            // Timestamp ordering prevents an older START from resurrecting a STOP.
            // STOP wins ties. Commands are best-effort Data Layer messages.
            if (issued < previousIssued ||
                (issued == previousIssued && previousCommand == "STOP" && command == "START")) {
                Log.i(TAG, "SESSION_CONTROL_REJECTED_OLD")
                return
            }
            if (command == "START") {
                if (issued == previousIssued && previousCommand == "START" &&
                    prefs.getString("active_session", "") == id) return
                prefs.edit()
                    .putString("active_session", id)
                    .putLong("last_issued_ms", issued)
                    .putString("last_command", "START")
                    .apply()
                Log.i(TAG, "SESSION_START_ACCEPTED id=$id")
            } else {
                // Only a matching STOP may end an existing active hike.
                val active = prefs.getString("active_session", "") ?: ""
                if (active.isNotEmpty() && active != id) {
                    Log.i(TAG, "SESSION_STOP_REJECTED_DIFFERENT_SESSION")
                    return
                }
                prefs.edit()
                    .remove("active_session")
                    .putLong("last_issued_ms", issued)
                    .putString("last_command", "STOP")
                    .apply()
                Log.i(TAG, "SESSION_STOP_ACCEPTED id=$id")
            }
        } catch (ex: Exception) {
            Log.e(TAG, "SESSION_CONTROL_FAILED", ex)
        }
    }

    // STEP412I_SENSOR_GUIDANCE_HANDLER
    // Experimental rule-based guidance, NOT a trained AI risk prediction.
    private fun handleSensorGuidance(json: JSONObject) {
        if (json.optInt("version", -1) != 1 ||
            json.optString("type") != "SENSOR_GUIDANCE") {
            Log.w(TAG, "SENSOR_GUIDANCE_REJECTED_PROTOCOL")
            return
        }

        val category = json.optString("category")
        val sessionId = json.optString("session_id")
        val eventId = json.optString("event_id")
        val timestamp = json.optLong("timestamp_ms", 0L)
        val now = System.currentTimeMillis()
        val age = now - timestamp

        val messages = mapOf(
            "heart_rate_unavailable" to Pair(
                "Heart Rate Unavailable",
                "Check Watch6 fit and sensor contact."
            ),
            "weather_unavailable" to Pair(
                "Weather Data Unavailable",
                "Check phone location and weather connection."
            ),
            "fatigue_caution" to Pair(
                "Fatigue-Related Caution",
                "Consider reducing effort and taking a rest break."
            ),
            "physical_strain_caution" to Pair(
                "Physical-Strain Caution",
                "Consider slowing down and checking perceived effort."
            ),
            "heat_exposure_caution" to Pair(
                "Heat-Exposure Caution",
                "Consider shade, pacing adjustments and a rest break."
            )
        )

        val guidance = messages[category]

        if (guidance == null ||
            sessionId.isBlank() ||
            sessionId.length > 64 ||
            !sessionId.all { it.isDigit() } ||
            eventId.isBlank() ||
            eventId.length > 160 ||
            timestamp <= 0L ||
            age < -30000L ||
            age > 120000L) {
            Log.w(TAG, "SENSOR_GUIDANCE_REJECTED_INVALID")
            return
        }

        val sessionPrefs = getSharedPreferences(
            SESSION_PREFS, MODE_PRIVATE
        )
        val activeSession = sessionPrefs.getString(
            "active_session", ""
        ) ?: ""

        if (activeSession.isBlank() || activeSession != sessionId) {
            Log.w(TAG, "SENSOR_GUIDANCE_REJECTED_SESSION")
            return
        }

        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "SENSOR_GUIDANCE_PERMISSION_MISSING")
            return
        }

        val prefs = getSharedPreferences(
            "component3_watch_sensor_guidance_v2", MODE_PRIVATE
        )

        val lastEvent = prefs.getString("last_event_$category", "")
        val lastTime = prefs.getLong("last_time_$category", 0L)
        val lastSession = prefs.getString("last_session_$category", "")

        if (eventId == lastEvent ||
            (lastSession == sessionId &&
                lastTime > 0L &&
                now >= lastTime &&
                now - lastTime < 120000L)) {
            Log.i(TAG, "SENSOR_GUIDANCE_DUPLICATE_OR_COOLDOWN category=$category")
            return
        }

        val manager = getSystemService(
            NotificationManager::class.java
        ) ?: return

        val channelId = "component3_sensor_guidance_watch_v2"

        val channel = NotificationChannel(
            channelId,
            "Hiking Safety Guidance",
            NotificationManager.IMPORTANCE_HIGH
        )
        channel.enableVibration(true)
        channel.vibrationPattern = longArrayOf(
            0L, 250L, 150L, 250L
        )
        manager.createNotificationChannel(channel)

        val notification = Notification.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(guidance.first)
            .setContentText(guidance.second)
            .setStyle(
                Notification.BigTextStyle().bigText(
                    "${guidance.second}\nRule-based guidance only. Not an AI risk prediction or medical diagnosis."
                )
            )
            .setCategory(Notification.CATEGORY_RECOMMENDATION)
            .setAutoCancel(true)
            .build()

        manager.notify(category.hashCode(), notification)

        prefs.edit()
            .putString("last_event_$category", eventId)
            .putLong("last_time_$category", now)
            .putString("last_session_$category", sessionId)
            .apply()

        Log.i(TAG, "SENSOR_GUIDANCE_NOTIFICATION_POSTED category=$category")
    }
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path == SESSION_PATH) {
            handleSessionControl(event)
            return
        }
        if (event.path != PATH) return

        try {
            if (event.data.size > 8192) {
                Log.w(TAG, "ALERT_REJECTED_OVERSIZE")
                return
            }

            val json = JSONObject(
                String(event.data, Charsets.UTF_8)
            )

            if (json.optString("type") == "SENSOR_GUIDANCE") {
                handleSensorGuidance(json)
                return
            }

            if (json.optInt("version", -1) == 1 &&
                json.optString("type") == "AI_RECOMMENDATION_TEST") {
                showControlledTestNotification(json)
                return
            }
            if (json.optInt("version", -1) != 1 ||
                json.optString("type") != "AI_RECOMMENDATION") {
                Log.w(TAG, "ALERT_REJECTED_PROTOCOL")
                return
            }

            val indicator = json.optString("indicator")
            val status = json.optString("status")
            val message = json.optString("message")
            val eventId = json.optString("event_id")
            val sessionId = json.optString("session_id")
            val timestamp = json.optLong("timestamp_ms", 0L)
            val now = System.currentTimeMillis()
            val age = now - timestamp

            // Synthetic TEST alerts bypass session validation intentionally.
            // Production AI alerts fail closed if START has not reached this watch.
            val sessionPrefs = getSharedPreferences(SESSION_PREFS, MODE_PRIVATE)
            val watchActive = sessionPrefs.getString("active_session", "") ?: ""
            if (watchActive.isBlank() || watchActive != sessionId) {
                Log.i(TAG, "AI_ALERT_REJECTED_INACTIVE_OR_WRONG_SESSION")
                return
            }

            val allowed = setOf(
                "fatigue_related",
                "physical_strain_related",
                "heat_exposure_related"
            )

            if (indicator !in allowed ||
                status != "elevated_context" ||
                message.isBlank() ||
                message.length > 500 ||
                eventId.isBlank() ||
                eventId.length > 160 ||
                sessionId.isBlank() ||
                timestamp <= 0L ||
                age < -30000L ||
                age > MAX_AGE_MS) {
                Log.w(TAG, "ALERT_REJECTED_VALIDATION")
                return
            }

            val prefs = getSharedPreferences(
                "component3_watch_alerts", MODE_PRIVATE
            )
            val key = "last_${indicator}"
            val lastTime = prefs.getLong(key, 0L)
            val lastEvent = prefs.getString("event_id", "")

            if (eventId == lastEvent ||
                (lastTime > 0L && now >= lastTime &&
                    now - lastTime < COOLDOWN_MS)) {
                Log.i(TAG, "ALERT_DUPLICATE_OR_COOLDOWN")
                return
            }

            if (Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED) {
                Log.w(TAG, "ALERT_PERMISSION_MISSING")
                return
            }

            val manager = getSystemService(
                NotificationManager::class.java
            )

            if (manager == null) {
                Log.w(TAG, "ALERT_MANAGER_UNAVAILABLE")
                return
            }

            val channel = NotificationChannel(
                CHANNEL_ID,
                "Experimental Hiking AI Alerts",
                NotificationManager.IMPORTANCE_HIGH
            )
            channel.description =
                "Non-diagnostic hiking indicator recommendations"
            channel.enableVibration(true)
            channel.vibrationPattern =
                longArrayOf(0L, 250L, 150L, 250L)

            manager.createNotificationChannel(channel)

            val title = when (indicator) {
                "fatigue_related" -> "Fatigue indicator elevated"
                "physical_strain_related" ->
                    "Physical strain indicator elevated"
                else -> "Heat exposure indicator elevated"
            }

            val notification = Notification.Builder(
                this, CHANNEL_ID
            )
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(message)
                .setStyle(
                    Notification.BigTextStyle()
                        .bigText(
                            "$message\nExperimental estimate; not a medical diagnosis."
                        )
                )
                .setCategory(Notification.CATEGORY_RECOMMENDATION)
                .setAutoCancel(true)
                .build()

            manager.notify(indicator.hashCode(), notification)

            prefs.edit()
                .putLong(key, now)
                .putString("event_id", eventId)
                .apply()

            Log.i(TAG, "AI_ALERT_NOTIFICATION_POSTED indicator=$indicator")

        } catch (ex: Exception) {
            Log.e(TAG, "AI_ALERT_RECEIVE_FAILED", ex)
        }
    }
}