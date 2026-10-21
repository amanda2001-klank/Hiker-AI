package com.example.app_venture.watch

import android.app.Service
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.health.services.client.ExerciseClient
import androidx.health.services.client.ExerciseUpdateCallback
import androidx.health.services.client.HealthServices
import androidx.health.services.client.data.*
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.*
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.guava.await
import kotlinx.coroutines.tasks.await as playServicesAwait

class ExerciseClientService : Service() {

    private val TAG = "ExerciseClientService"

    private lateinit var exerciseClient: ExerciseClient

    private val serviceScope = CoroutineScope(
        Dispatchers.IO + SupervisorJob()
    )

    private enum class ExerciseState { IDLE, STARTING, TRACKING, STOPPING }

    @Volatile
    private var exerciseState = ExerciseState.IDLE

    @Volatile
    private var stopRequested = false

    private val operationMutex = Mutex()
    private var timeoutJob: Job? = null
    private var callbackRegistered = false
    private var foregroundStarted = false
    private var cleanupCompletedInThisInstance = false

    private var lastHr: Double? = null

    // BORG_HR_SAMPLE_AGE_V1
    private var lastHrSampleElapsedMs: Long? = null
    private var lastSteps: Double? = null
    private var lastDistance: Double? = null
    private var lastCalories: Double? = null

    private val exerciseUpdateCallback =
        object : ExerciseUpdateCallback {

            override fun onExerciseUpdateReceived(
                update: ExerciseUpdate
            ) {
                val metrics = update.latestMetrics

                // Heart rate: sample data
                metrics.sampleDataPoints
                    .lastOrNull {
                        it.dataType == DataType.HEART_RATE_BPM
                    }?.let { point ->
                        lastHr = (point.value as Number).toDouble()
                        lastHrSampleElapsedMs =
                            point.timeDurationFromBoot.toMillis()
                        Log.d(
                            "Watch6SensorTest",
                            "Heart rate BPM: $lastHr"
                        )
                    }

                // Steps: cumulative data
                metrics.cumulativeDataPoints
                    .lastOrNull {
                        it.dataType == DataType.STEPS_TOTAL
                    }?.let { point ->
                        lastSteps = point.total.toDouble()
                    }

                // Distance: cumulative data, metres
                metrics.cumulativeDataPoints
                    .lastOrNull {
                        it.dataType == DataType.DISTANCE_TOTAL
                    }?.let { point ->
                        lastDistance = point.total.toDouble()
                    }

                // Calories: cumulative data
                metrics.cumulativeDataPoints
                    .lastOrNull {
                        it.dataType == DataType.CALORIES_TOTAL
                    }?.let { point ->
                        lastCalories = point.total.toDouble()
                    }

                val hr = lastHr
                val steps = lastSteps
                val distance = lastDistance
                val calories = lastCalories

                if (exerciseState == ExerciseState.TRACKING) {
                    serviceScope.launch {
                        sendTelemetryToPhone(
                            hr,
                            lastHrSampleElapsedMs,
                            steps,
                            distance,
                            calories
                        )
                    }
                }
            }

            override fun onLapSummaryReceived(
                lapSummary: ExerciseLapSummary
            ) {
                Log.d(TAG, "Lap summary received")
            }

            override fun onAvailabilityChanged(
                dataType: DataType<*, *>,
                availability: Availability
            ) {
                Log.d(
                    TAG,
                    "Availability changed: $dataType -> $availability"
                )
            }

            override fun onRegistered() {
                Log.d(TAG, "Exercise callback registered")
            }

            override fun onRegistrationFailed(
                throwable: Throwable
            ) {
                Log.e(
                    TAG,
                    "Exercise callback registration failed",
                    throwable
                )
            }
        }

    override fun onCreate() {
        super.onCreate()

        exerciseClient =
            HealthServices.getClient(this).exerciseClient
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {
        when (intent?.action) {
            "ACTION_START_EXERCISE" -> startHikeExercise()
            "ACTION_STOP_EXERCISE" -> stopHikeExercise()
            // Pause/resume are not part of the independent HR-only test.
            "ACTION_PAUSE_EXERCISE", "ACTION_RESUME_EXERCISE" ->
                Log.w(TAG, "Pause/resume disabled in sensor test")
            else -> {
                Log.w(TAG, "Unknown service action; stopping")
                stopSelfResult(startId)
            }
        }
        return START_NOT_STICKY
    }

    private fun startSensorForeground() {
        val channelId = "watch6_sensor_test"

        val manager =
            getSystemService(NotificationManager::class.java)

        val channel = NotificationChannel(
            channelId,
            "Watch6 Sensor Test",
            NotificationManager.IMPORTANCE_LOW
        )

        manager.createNotificationChannel(channel)

        val notification = Notification.Builder(this, channelId)
            .setContentTitle("Watch6 Sensor Test")
            .setContentText("Heart-rate research test is active")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setOngoing(true)
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                1001,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_HEALTH
            )
        } else {
            startForeground(1001, notification)
        }

        Log.d(TAG, "Foreground health service started")
    }

    @Synchronized
    private fun startHikeExercise() {
        if (exerciseState != ExerciseState.IDLE) {
            Log.d(TAG, "Duplicate start ignored: $exerciseState")
            return
        }

        exerciseState = ExerciseState.STARTING
        stopRequested = false

        // Foreground promotion must be immediate after startForegroundService().
        try {
            startSensorForeground()
            foregroundStarted = true
        } catch (e: Exception) {
            Log.e(TAG, "Foreground startup failed", e)
            exerciseState = ExerciseState.IDLE
            stopSelf()
            return
        }

        serviceScope.launch {
            operationMutex.withLock {
                try {
                    if (stopRequested) {
                        Log.d(TAG, "Stop requested before exercise startup")
                        return@withLock
                    }

                    val capabilities = exerciseClient.getCapabilitiesAsync().await()
                    if (!capabilities.supportedExerciseTypes.contains(ExerciseType.HIKING)) {
                        Log.w(TAG, "HIKING exercise not supported")
                        return@withLock
                    }

                    val config = ExerciseConfig.Builder(ExerciseType.HIKING)
                        .setDataTypes(setOf(DataType.HEART_RATE_BPM, DataType.STEPS_TOTAL))
                        .setIsGpsEnabled(false)
                        .build()

                    callbackRegistered = true
                    exerciseClient.setUpdateCallback(exerciseUpdateCallback)
                    exerciseClient.startExerciseAsync(config).await()
                    exerciseState = ExerciseState.TRACKING
                    Log.d(TAG, "Hiking exercise started successfully")

                    if (stopRequested) {
                        Log.d(TAG, "Stop requested during startup")
                    } else {
                        timeoutJob = serviceScope.launch {
                            delay(1_200_000L)
                            Log.d(TAG, "Short sensor test timeout reached")
                            stopHikeExercise()
                        }
                        return@withLock
                    }
                } catch (e: CancellationException) {
                    Log.w(TAG, "Exercise startup coroutine cancelled")
                    throw e
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start hiking exercise", e)
                } finally {
                    // Cleanup when startup did not reach steady TRACKING state,
                    // including queued Stop or an exception.
                    if (exerciseState != ExerciseState.TRACKING || stopRequested) {
                        cleanupExercise()
                    }
                }
            }
        }
    }

    private suspend fun cleanupExercise() {
        // This function runs under operationMutex; callers serialize start/stop.
        exerciseState = ExerciseState.STOPPING
        timeoutJob?.cancel()
        timeoutJob = null

        withContext(NonCancellable) {
            try {
                val ended = withTimeoutOrNull(10_000L) {
                    exerciseClient.endExerciseAsync().await()
                    true
                }
                if (ended == true) Log.d(TAG, "Exercise stopped successfully")
                else Log.w(TAG, "Exercise end timed out")
            } catch (e: Exception) {
                Log.w(TAG, "Exercise end failed or no active exercise: ${e.message}")
            }

            if (callbackRegistered) {
                try {
                    val cleared = withTimeoutOrNull(5_000L) {
                        exerciseClient.clearUpdateCallbackAsync(exerciseUpdateCallback).await()
                        true
                    }
                    if (cleared != true) Log.w(TAG, "Callback clear timed out")
                } catch (e: Exception) {
                    Log.w(TAG, "Could not clear exercise callback", e)
                }
                callbackRegistered = false
            }
            lastHr = null
            lastHrSampleElapsedMs = null
            lastSteps = null
            lastDistance = null
            lastCalories = null
            if (foregroundStarted) {
                try {
                    stopForeground(STOP_FOREGROUND_REMOVE)
                } catch (e: Exception) {
                    Log.w(TAG, "Could not remove foreground notification", e)
                }
                foregroundStarted = false
            }
            exerciseState = ExerciseState.IDLE
            stopRequested = false
            cleanupCompletedInThisInstance = true
            stopSelf()
            Log.d(TAG, "Sensor test cleanup completed")
        }
    }

    private suspend fun sendTelemetryToPhone(
        hr: Double?,
        hrSampleElapsedMs: Long?,
        steps: Double?,
        distance: Double?,
        calories: Double?
    ) {
        try {
            val nodes =
                Wearable.getNodeClient(this)
                    .connectedNodes
                    .playServicesAwait()

            val messageClient =
                Wearable.getMessageClient(this)

            val sampleAgeMs = hrSampleElapsedMs?.let {
                android.os.SystemClock.elapsedRealtime() - it
            }

            val freshHr =
                if (hr != null &&
                    sampleAgeMs != null &&
                    sampleAgeMs >= 0L &&
                    sampleAgeMs <= 10000L) hr
                else null

            val payloadJson =
                org.json.JSONObject().apply {
                    put("version", 1)
                    put(
                        "timestamp",
                        System.currentTimeMillis()
                    )
                    put(
                        "heartRate",
                        freshHr ?: org.json.JSONObject.NULL
                    )
                    put(
                        "hrSampleAgeMs",
                        if (freshHr != null) sampleAgeMs
                        else org.json.JSONObject.NULL
                    )
                    put(
                        "stepCount",
                        steps?.toInt() ?: org.json.JSONObject.NULL
                    )
                    put(
                        "distanceKm",
                        distance?.div(1000.0)
                            ?: org.json.JSONObject.NULL
                    )
                    put(
                        "calories",
                        calories ?: org.json.JSONObject.NULL
                    )
                }.toString()

            val payloadBytes =
                payloadJson.toByteArray(Charsets.UTF_8)

            for (node in nodes) {
                messageClient.sendMessage(
                    node.id,
                    "/venture_hike/telemetry",
                    payloadBytes
                ).playServicesAwait()
            }

            Log.d(TAG, "Telemetry sent: $payloadJson")

        } catch (e: Exception) {
            Log.e(
                TAG,
                "Failed to send telemetry",
                e
            )
        }
    }

    private fun pauseHikeExercise() {
        serviceScope.launch {
            try {
                exerciseClient.pauseExerciseAsync().await()
                Log.d(TAG, "Exercise paused")
            } catch (e: Exception) {
                Log.e(TAG, "Pause failed", e)
            }
        }
    }

    private fun resumeHikeExercise() {
        serviceScope.launch {
            try {
                exerciseClient.resumeExerciseAsync().await()
                Log.d(TAG, "Exercise resumed")
            } catch (e: Exception) {
                Log.e(TAG, "Resume failed", e)
            }
        }
    }

    @Synchronized
    private fun stopHikeExercise() {
        stopRequested = true
        Log.d(TAG, "Stop requested; current state: $exerciseState")

        // Wait for any in-progress startup before ending the exercise.
        serviceScope.launch {
            operationMutex.withLock {
                when (exerciseState) {
                    ExerciseState.STOPPING -> {
                        Log.d(TAG, "Duplicate Stop ignored: already stopping")
                    }
                    ExerciseState.IDLE -> {
                        if (cleanupCompletedInThisInstance) {
                            Log.d(TAG, "Duplicate Stop ignored: cleanup completed")
                            stopSelf()
                        } else {
                            // A newly created service may have an orphaned exercise.
                            Log.d(TAG, "Checking possible orphaned exercise")
                            cleanupExercise()
                        }
                    }
                    else -> cleanupExercise()
                }
            }
        }
    }

    override fun onDestroy() {
        if (exerciseState != ExerciseState.IDLE) {
            Log.w(TAG, "Service destroyed while exercise state is $exerciseState")
        }
        timeoutJob?.cancel()
        serviceScope.cancel()
        super.onDestroy()
    }
}
