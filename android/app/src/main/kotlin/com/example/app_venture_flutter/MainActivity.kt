package com.example.app_venture_flutter

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val METHOD_CHANNEL = "com.example.app_venture_flutter/wearable"
    private val EVENT_CHANNEL = "com.example.app_venture_flutter/wearable_stream"
    private lateinit var bridge: WatchCompanionBridge

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = WatchCompanionBridge(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler(bridge)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(bridge)

        // Isolated MANUAL phone notification test.
        // Never connected to live model inference or recommendations.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.app_venture_flutter/component3_phone_test_alert"
        ).setMethodCallHandler { call, result ->
            if (call.method != "showTestPhoneAlert") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            if (android.os.Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                    android.content.pm.PackageManager.PERMISSION_GRANTED) {
                result.error(
                    "NOTIFICATION_PERMISSION_REQUIRED",
                    "Enable notification permission for the testing app in Android Settings.",
                    null
                )
                return@setMethodCallHandler
            }

            try {
                result.success(Component3PhoneTestAlert(this).showTestAlert())
            } catch (e: Exception) {
                result.error("PHONE_TEST_ALERT_FAILED", e.message, null)
            }
        }
        // Automatic sensor-quality guidance only, never an AI risk score.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.app_venture_flutter/component3_phone_guidance"
        ).setMethodCallHandler { call, result ->
            if (call.method != "showSensorGuidance") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val category = call.argument<String>("category")

            if (category == null) {
                result.error("INVALID_GUIDANCE", "Missing category", null)
                return@setMethodCallHandler
            }

            try {
                result.success(Component3PhoneGuidance(this).show(category))
            } catch (e: Exception) {
                result.error("PHONE_GUIDANCE_FAILED", e.message, null)
            }
        }
        // Isolated research smoke test. No live predictions or alerts.
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.app_venture_flutter/risk_tflite_test"
        ).setMethodCallHandler { call, result ->
            if (call.method != "smokeTest" && call.method != "predictNormalized") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            Thread {
                try {
                    val bridge = RiskTfliteBridge(applicationContext)
                    val output = if (call.method == "smokeTest") {
                        bridge.smokeTest()
                    } else {
                        val outer = call.argument<List<*>>("rows")
                            ?: throw IllegalArgumentException("Missing normalized rows")
                        val rows = outer.map { row ->
                            require(row is List<*>) { "Expected rows as lists" }
                            row.map { cell ->
                                require(cell is Number) { "Non-numeric model input" }
                                cell.toDouble()
                            }
                        }
                        bridge.predictNormalized(rows)
                    }
                    runOnUiThread {
                        result.success(output)
                    }
                } catch (e: Exception) {
                    runOnUiThread {
                        result.error(
                            "TFLITE_TEST_ERROR",
                            e.message ?: e.javaClass.simpleName,
                            null
                        )
                    }
                }
            }.start()
        }
        val onnxBridge = OnnxInferenceBridge(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.example.app_venture_flutter/onnx_ai"
        ).setMethodCallHandler { call, result ->

            if (call.method != "predictExertion") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val hr = call.argument<Number>("heartRate")?.toDouble()
            val age = call.argument<Number>("age")?.toDouble()
            val years = call.argument<Number>("fitnessYears")?.toDouble()
            val sleep = call.argument<Number>("sleepingHours")?.toDouble()

            if (hr == null || age == null ||
                years == null || sleep == null) {
                result.error(
                    "MISSING_INPUT",
                    "Real HR and complete user profile required",
                    null
                )
                return@setMethodCallHandler
            }

            Thread {
                try {
                    val score = onnxBridge.predict(
                        hr, age, years, sleep
                    )

                    runOnUiThread {
                        result.success(score)
                    }

                } catch (e: IllegalArgumentException) {
                    runOnUiThread {
                        result.error(
                            "INVALID_INPUT",
                            e.message,
                            null
                        )
                    }

                } catch (e: Exception) {
                    runOnUiThread {
                        result.error(
                            "ONNX_ERROR",
                            e.message,
                            null
                        )
                    }
                }
            }.start()
        }
    }
}
