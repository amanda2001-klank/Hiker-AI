package com.example.app_venture_flutter

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log

class Component3PhoneTestAlert(private val activity: Activity) {

    companion object {
        private const val TAG = "PhoneAiTestAlert"
        private const val CHANNEL_ID = "component3_phone_test_alerts_v1"
        private const val NOTIFICATION_ID = 32001
    }

    fun showTestAlert(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "TEST_ALERT_PERMISSION_MISSING")
            return false
        }

        val manager =
            activity.getSystemService(NotificationManager::class.java)
                ?: return false

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Hiking AI Phone Test Alerts",
            NotificationManager.IMPORTANCE_HIGH
        )

        channel.description =
            "Manual notification and vibration delivery testing only"
        channel.enableVibration(true)
        channel.vibrationPattern = longArrayOf(0L, 300L, 180L, 300L)
        manager.createNotificationChannel(channel)

        val notification = Notification.Builder(activity, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("TEST ALERT ONLY - Hiking AI")
            .setContentText(
                "Phone notification and vibration test. No real risk detected."
            )
            .setStyle(
                Notification.BigTextStyle().bigText(
                    "MANUAL TEST ONLY. This notification checks phone " +
                    "notification and vibration delivery. It is not an AI " +
                    "risk prediction or medical warning."
                )
            )
            .setAutoCancel(true)
            .build()

        manager.notify(NOTIFICATION_ID, notification)
        Log.i(TAG, "PHONE_TEST_ALERT_NOTIFICATION_POSTED")
        return true
    }
}