package com.example.app_venture_flutter

import android.Manifest
import android.app.Activity
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.pm.PackageManager
import android.os.Build

class Component3PhoneGuidance(private val activity: Activity) {
    fun show(category: String): Boolean {
        if (category !in setOf(
                "heart_rate_unavailable",
                "weather_unavailable",
                "fatigue_caution",
                "physical_strain_caution",
                "heat_exposure_caution"
            )) return false

        if (Build.VERSION.SDK_INT >= 33 &&
            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) return false

        val manager = activity.getSystemService(
            NotificationManager::class.java
        ) ?: return false

        val channelId = "component3_sensor_guidance_phone_v1"
        val channel = NotificationChannel(
            channelId,
            "Hiking Sensor Guidance",
            NotificationManager.IMPORTANCE_DEFAULT
        )
        channel.enableVibration(true)
        channel.vibrationPattern = longArrayOf(0L, 200L, 150L, 200L)
        manager.createNotificationChannel(channel)

        val title: String
        val message: String

        // STEP393B_RULE_SAFETY
        // Non-diagnostic rule-based cautions; not AI predictions.
        when (category) {
            "heart_rate_unavailable" -> {
                title = "Check Watch6 heart-rate sensor"
                message = "Heart-rate data is unavailable or stale. " +
                    "Check watch fit and sensor contact."
            }
            "weather_unavailable" -> {
                title = "Weather data unavailable"
                message = "Check phone location and internet connection."
            }
            "fatigue_caution" -> {
                title = "Fatigue-related hiking caution"
                message = "Consider reducing effort and taking a rest break."
            }
            "physical_strain_caution" -> {
                title = "Physical-strain-related caution"
                message = "Consider slowing down and checking perceived effort."
            }
            "heat_exposure_caution" -> {
                title = "Heat-exposure caution"
                message = "Consider shade, pacing adjustments and a rest break."
            }
            else -> return false
        }
        val notification = Notification.Builder(activity, channelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(Notification.BigTextStyle().bigText(message))
            .setAutoCancel(true)
            .build()

        manager.notify(category.hashCode(), notification)
        return true
    }
}