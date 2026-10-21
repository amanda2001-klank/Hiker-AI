package com.example.app_venture_flutter

import android.content.Context
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.Collections

class OnnxInferenceBridge(private val context: Context) {

    fun predict(
        heartRate: Double,
        age: Double,
        fitnessYears: Double,
        sleepingHours: Double
    ): Double {

        require(heartRate.isFinite() && heartRate in 60.0..99.0) {
            "HR outside validated engine input range (60-99 BPM)"
        }

        require(age.isFinite() && age > 0.0 && age <= 120.0) {
            "Invalid age"
        }

        require(fitnessYears.isFinite() &&
                fitnessYears >= 0.0 &&
                fitnessYears <= age) {
            "Invalid fitness training years"
        }

        require(sleepingHours.isFinite() &&
                sleepingHours >= 0.0 &&
                sleepingHours <= 24.0) {
            "Invalid sleeping hours"
        }

        val inputValues = floatArrayOf(
            heartRate.toFloat(),
            age.toFloat(),
            fitnessYears.toFloat(),
            sleepingHours.toFloat()
        )

        val bytes = context.assets.open("hiking_exertion_rf.onnx")
            .use { it.readBytes() }

        val env = OrtEnvironment.getEnvironment()

        env.createSession(bytes, OrtSession.SessionOptions()).use { session ->

            val buffer = ByteBuffer
                .allocateDirect(4 * Float.SIZE_BYTES)
                .order(ByteOrder.nativeOrder())
                .asFloatBuffer()

            buffer.put(inputValues)
            buffer.rewind()

            val inputName = session.inputNames.single()

            OnnxTensor.createTensor(
                env,
                buffer,
                longArrayOf(1, 4)
            ).use { tensor ->

                session.run(
                    Collections.singletonMap(inputName, tensor)
                ).use { result ->

                    val raw = result[0].value
                    val rows = raw as? Array<*>
                        ?: error("Unexpected ONNX output type")

                    val values = rows.singleOrNull() as? FloatArray
                        ?: error("Unexpected ONNX output shape")

                    require(values.size == 1 && values[0].isFinite()) {
                        "Invalid ONNX prediction"
                    }

                    return values[0].toDouble()
                }
            }
        }
    }
}
