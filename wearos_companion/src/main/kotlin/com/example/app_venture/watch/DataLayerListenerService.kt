package com.example.app_venture.watch

import android.content.Intent
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class DataLayerListenerService : WearableListenerService() {
    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        val intent = Intent(this, ExerciseClientService::class.java)
        when (messageEvent.path) {
            "/venture_hike/start" -> {
                intent.action = "ACTION_START_EXERCISE"
                startForegroundService(intent)
            }
            "/venture_hike/pause" -> {
                intent.action = "ACTION_PAUSE_EXERCISE"
                startService(intent)
            }
            "/venture_hike/resume" -> {
                intent.action = "ACTION_RESUME_EXERCISE"
                startService(intent)
            }
            "/venture_hike/stop" -> {
                intent.action = "ACTION_STOP_EXERCISE"
                startService(intent)
            }
        }
    }
}
