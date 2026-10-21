package com.example.app_venture_flutter

import android.content.Context
import android.util.Log
import com.google.android.gms.wearable.MessageClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

class WatchCompanionBridge(private val context: Context) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, MessageClient.OnMessageReceivedListener {

    private var eventSink: EventChannel.EventSink? = null
    private val scope = CoroutineScope(Dispatchers.Main)
    private val TAG = "WatchCompanionBridge"

    // Phase 2: Reject duplicate/out-of-order telemetry per source watch.
    // The timestamp is created by the watch; never fabricate one for deduplication.
    private val sequenceLock = Any()
    private val latestTimestampBySource = mutableMapOf<String, Long>()

    override fun onMessageReceived(messageEvent: MessageEvent) {
        if (messageEvent.path != "/venture_hike/telemetry") return

        try {
            val jsonString = String(messageEvent.data, Charsets.UTF_8)
            val json = JSONObject(jsonString)

            fun nullableDouble(key: String): Double? {
                if (json.isNull(key) || !json.has(key)) return null
                val d = json.optDouble(key)
                if (d.toString() == "NaN" || d.toString() == "Infinity") return null
                return d
            }

            fun nullableInt(key: String): Int? {
                if (json.isNull(key) || !json.has(key)) return null
                return json.optInt(key)
            }

            val timestamp = if (json.has("timestamp") && !json.isNull("timestamp")) {
                json.optLong("timestamp", -1L)
            } else {
                -1L
            }
            if (timestamp <= 0L) {
                Log.w(TAG, "Ignoring telemetry with missing/invalid source timestamp")
                return
            }

            val dataMap = mapOf<String, Any?>(
                "timestamp" to timestamp.toString(),
                "heartRate" to nullableDouble("heartRate"),
                "stepCount" to nullableInt("stepCount"),
                "distanceKm" to nullableDouble("distanceKm"),
                "calories" to nullableDouble("calories"),
                "elevationM" to nullableDouble("elevationM")
            )

            val source = messageEvent.sourceNodeId
            val accepted = synchronized(sequenceLock) {
                val previous = latestTimestampBySource[source]
                if (previous != null && timestamp <= previous) {
                    false
                } else {
                    latestTimestampBySource[source] = timestamp
                    true
                }
            }
            if (!accepted) {
                Log.v(TAG, "Dropped duplicate/out-of-order telemetry source=$source timestamp=$timestamp")
                return
            }

            Log.d(TAG, "Phone received watch telemetry: $dataMap")

            scope.launch {
                eventSink?.success(dataMap)
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error parsing watch telemetry", e)
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "connect" -> {
                scope.launch {
                    try {
                        val nodes = Wearable.getNodeClient(context)
                            .connectedNodes
                            .await()

                        Log.d(TAG, "Connected Wear OS nodes: ${nodes.size}")

                        val watchNode = nodes.firstOrNull { it.isNearby }
                            ?: nodes.firstOrNull()

                        if (watchNode == null) {
                            Log.w(TAG, "No connected Wear OS watch found")
                            result.success(false)
                            return@launch
                        }

                        Log.d(
                            TAG,
                            "Watch node found: ${watchNode.displayName}, ID=${watchNode.id}"
                        )

                        result.success(true)

                    } catch (e: Exception) {
                        Log.e(TAG, "Watch discovery failed", e)
                        result.success(false)
                    }
                }
            }
            "startExercise" -> {
                sendMessageToWatch("/venture_hike/start", "{\"version\":1,\"type\":\"START_EXERCISE\"}".toByteArray(Charsets.UTF_8), result)
            }
            "pauseExercise" -> {
                sendMessageToWatch("/venture_hike/pause", "{\"version\":1,\"type\":\"PAUSE_EXERCISE\"}".toByteArray(Charsets.UTF_8), result)
            }
            "resumeExercise" -> {
                sendMessageToWatch("/venture_hike/resume", "{\"version\":1,\"type\":\"RESUME_EXERCISE\"}".toByteArray(Charsets.UTF_8), result)
            }
            "stopExercise" -> {
                sendMessageToWatch("/venture_hike/stop", "{\"version\":1,\"type\":\"STOP_EXERCISE\"}".toByteArray(Charsets.UTF_8), result)
            }
            // STEP367_SENSOR_GUIDANCE
            // Sensor availability guidance only; no AI risk inference.
            // STEP369_SESSION_CONTROL
            // Separate lifecycle for non-diagnostic sensor guidance.
            "setGuidanceSession" -> {
                val command = call.argument<String>("command")
                val sessionId = call.argument<String>("session_id")

                if (command !in setOf("START", "STOP") ||
                    sessionId.isNullOrBlank() ||
                    sessionId.length > 64 ||
                    !sessionId.all { it.isDigit() }) {
                    result.error(
                        "INVALID_SESSION",
                        "START/STOP and numeric session_id required",
                        null
                    )
                    return
                }

                val payload = org.json.JSONObject().apply {
                    put("version", 1)
                    put("type", "HIKE_SESSION_CONTROL")
                    put("command", command)
                    put("session_id", sessionId)
                    put("issued_ms", System.currentTimeMillis())
                }.toString().toByteArray(Charsets.UTF_8)

                sendMessageToWatch(
                    "/venture_hike/ai_session",
                    payload,
                    result
                )
            }
            "sendSensorGuidance" -> {
                val category = call.argument<String>("category")
                val sessionId = call.argument<String>("session_id")

                if (category !in setOf(
// STEP393D_RULE_SAFETY
                        "heart_rate_unavailable",
                        "weather_unavailable",
                        "fatigue_caution",
                        "physical_strain_caution",
                        "heat_exposure_caution"
                    ) ||
                    sessionId.isNullOrBlank() ||
                    sessionId.length > 64 ||
                    !sessionId.all { it.isDigit() }) {
                    result.error(
                        "INVALID_GUIDANCE",
                        "Valid category and numeric session required",
                        null
                    )
                    return
                }

                val payload = org.json.JSONObject().apply {
                    put("version", 1)
                    put("type", "SENSOR_GUIDANCE")
                    put("category", category)
                    put("session_id", sessionId)
                    put("event_id", java.util.UUID.randomUUID().toString())
                    put("timestamp_ms", System.currentTimeMillis())
                }.toString().toByteArray(Charsets.UTF_8)

                sendMessageToWatch(
                    "/venture_hike/ai_recommendation",
                    payload,
                    result
                )
            }
            "sendTestAiAlert" -> {
                val timestamp = System.currentTimeMillis()
                val eventId = "manual-test-${java.util.UUID.randomUUID()}"

                val payload = org.json.JSONObject().apply {
                    put("version", 1)
                    put("type", "AI_RECOMMENDATION_TEST")
                    put("event_id", eventId)
                    put("timestamp_ms", timestamp)
                }.toString().toByteArray(Charsets.UTF_8)

                sendMessageToWatch(
                    "/venture_hike/ai_recommendation",
                    payload,
                    result
                )
            }            "disconnect" -> {
                result.success(true)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun sendMessageToWatch(
        path: String,
        payload: ByteArray,
        result: MethodChannel.Result
    ) {
        scope.launch {
            try {
                val nodes = Wearable.getNodeClient(context)
                    .connectedNodes
                    .await()

                if (nodes.isEmpty()) {
                    result.error(
                        "NO_WATCH",
                        "No connected Wear OS watch found",
                        null
                    )
                    return@launch
                }

                val watchNode = nodes.firstOrNull { it.isNearby }
                    ?: nodes.first()

                val requestId = Wearable.getMessageClient(context)
                    .sendMessage(watchNode.id, path, payload)
                    .await()

                Log.d(
                    TAG,
                    "Message sent to ${watchNode.displayName}, path=$path, requestId=$requestId"
                )

                result.success(true)

            } catch (e: Exception) {
                Log.e(TAG, "Failed to send message: $path", e)
                result.error("SEND_FAILED", e.message, null)
            }
        }
    }

    override fun onListen(
        arguments: Any?,
        events: EventChannel.EventSink?
    ) {
        eventSink = events

        Wearable.getMessageClient(context)
            .addListener(this)
            .addOnSuccessListener {
                Log.d(TAG, "Watch telemetry listener active")
            }
            .addOnFailureListener { e: Exception ->
                Log.e(TAG, "Failed to activate listener", e)
            }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        synchronized(sequenceLock) {
            latestTimestampBySource.clear()
        }

        Wearable.getMessageClient(context)
            .removeListener(this)
    }
}
