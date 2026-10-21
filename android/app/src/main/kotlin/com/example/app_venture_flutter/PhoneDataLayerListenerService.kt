package com.example.app_venture_flutter

import android.util.Log
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

class PhoneDataLayerListenerService : WearableListenerService() {
    private val TAG = "PhoneDataLayerListener"

    override fun onMessageReceived(messageEvent: MessageEvent) {
        super.onMessageReceived(messageEvent)
        val dataSize = messageEvent.data?.size ?: 0
        Log.d(TAG, "onMessageReceived path=${messageEvent.path}, source=${messageEvent.sourceNodeId}, size=$dataSize")
    }
}
