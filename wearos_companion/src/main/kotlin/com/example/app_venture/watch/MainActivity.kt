package com.example.app_venture.watch

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class MainActivity : Activity() {

    private val permissionRequestCode = 1001

    private fun startExercise(actionName: String) {
        val intent = Intent(
            this,
            ExerciseClientService::class.java
        ).apply {
            action = actionName
        }

        if (actionName == "ACTION_START_EXERCISE") {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(24, 16, 24, 16)
        }

        val title = TextView(this).apply {
            text = "APP Venture"
            textSize = 20f
            gravity = Gravity.CENTER
        }

        val startButton = Button(this).apply {
            text = "Start Hiking"
            setOnClickListener {
                if (hasPermissions()) {
                    startExercise("ACTION_START_EXERCISE")
                } else {
                    requestPermissions()
                }
            }
        }

        val stopButton = Button(this).apply {
            text = "Stop Hiking"
            setOnClickListener {
                startExercise("ACTION_STOP_EXERCISE")
            }
        }

        layout.addView(title)
        layout.addView(startButton)
        layout.addView(stopButton)

        setContentView(layout)

        if (!hasPermissions()) {
            requestPermissions()
        }
    }

    private fun requiredPermissions(): Array<String> {
        val permissions = mutableListOf(
            Manifest.permission.BODY_SENSORS,
            Manifest.permission.ACTIVITY_RECOGNITION,
            Manifest.permission.ACCESS_FINE_LOCATION,
            "android.permission.health.READ_HEART_RATE"
        )

        if (Build.VERSION.SDK_INT >= 33) {
            permissions.add(
                Manifest.permission.POST_NOTIFICATIONS
            )
        }

        return permissions.toTypedArray()
    }

    private fun hasPermissions(): Boolean {
        return requiredPermissions().all {
            checkSelfPermission(it) ==
                PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestPermissions() {
        requestPermissions(
            requiredPermissions(),
            permissionRequestCode
        )
    }
}
