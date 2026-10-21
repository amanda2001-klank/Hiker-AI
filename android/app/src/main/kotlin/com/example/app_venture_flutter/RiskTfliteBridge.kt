package com.example.app_venture_flutter

import android.content.Context
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Research-only technical inference bridge.
 *
 * No live sensor inference, risk percentages or alerts.
 * Output index-to-indicator mapping remains unverified.
 */
class RiskTfliteBridge(private val context: Context) {

    private fun loadModel(): ByteBuffer {
        val bytes = context.assets.open("risk_model.tflite").use {
            it.readBytes()
        }

        return ByteBuffer
            .allocateDirect(bytes.size)
            .order(ByteOrder.nativeOrder())
            .apply {
                put(bytes)
                rewind()
            }
    }

    /** Technical inference only: caller must provide 10 verified, normalized rows.
     * Do not display as clinical probabilities or invoke with missing/fabricated data.
     */
    fun predictNormalized(rows: List<List<Double>>): Map<String, Any> {
        require(rows.size == 10 && rows.all { it.size == 12 }) {
            "Expected exactly 10 rows x 12 features"
        }
        require(rows.flatten().all { it.isFinite() && it.toFloat().isFinite() }) {
            "All features must be finite Float32 values"
        }
        val interpreter = Interpreter(loadModel(), Interpreter.Options())
        try {
            require(interpreter.getInputTensor(0).shape().contentEquals(intArrayOf(1, 10, 12))) {
                "Model input shape mismatch"
            }
            require(interpreter.outputTensorCount == 3) {
                "Model output count mismatch"
            }
            val input = arrayOf(rows.map { row -> row.map { it.toFloat() }.toFloatArray() }.toTypedArray())
            val outputs = mutableMapOf<Int, Any>()
            for (i in 0 until 3) {
                require(interpreter.getOutputTensor(i).shape().contentEquals(intArrayOf(1, 1))) {
                    "Model output $i shape mismatch"
                }
                outputs[i] = Array(1) { FloatArray(1) }
            }
            interpreter.runForMultipleInputsOutputs(arrayOf(input), outputs)
            val raw = (0 until 3).map { i ->
                val result = (outputs[i] as Array<*>)[0] as FloatArray
                result[0].toDouble().also { require(it.isFinite()) { "Non-finite output" } }
            }
            // TFLite tensor ordering differs from saved serving_default signature ordering.
            return mapOf(
                "status" to "technical_inference_only",
                "output_0" to raw[1],
                "output_1" to raw[0],
                "output_2" to raw[2],
                "live_inference_authorized" to false,
                "output_mapping_validated" to false,
                "clinical_validation" to false
            )
        } finally {
            interpreter.close()
        }
    }

    fun smokeTest(): Map<String, Any> {
        val model = loadModel()
        val interpreter = Interpreter(model, Interpreter.Options())

        try {
            val inputShape = interpreter.getInputTensor(0).shape()

            require(inputShape.contentEquals(intArrayOf(1, 10, 12))) {
                "Unexpected TFLite input shape: ${inputShape.contentToString()}"
            }

            require(interpreter.outputTensorCount == 3) {
                "Expected exactly three model output tensors"
            }

            // Explicitly synthetic NORMALIZED input for runtime testing only.
            // Never interpret these outputs as actual physiological risks.
            val input = Array(1) {
                Array(10) {
                    FloatArray(12) { 0.0f }
                }
            }

            val outputs = mutableMapOf<Int, Any>()

            for (index in 0 until 3) {
                val shape = interpreter.getOutputTensor(index).shape()

                require(shape.contentEquals(intArrayOf(1, 1))) {
                    "Unexpected output $index shape: ${shape.contentToString()}"
                }

                outputs[index] = Array(1) { FloatArray(1) }
            }

            interpreter.runForMultipleInputsOutputs(
                arrayOf(input),
                outputs
            )

            val values = (0 until 3).map { index ->
                val tensor = outputs[index] as Array<*>
                val row = tensor[0] as FloatArray
                val value = row[0]

                require(value.isFinite()) {
                    "Non-finite output at index $index"
                }

                value.toDouble()
            }

            // Verified against TFLite serving_default signature:
            // output_0 -> raw index 1
            // output_1 -> raw index 0
            // output_2 -> raw index 2
            val signatureValues = mapOf(
                "output_0" to values[1],
                "output_1" to values[0],
                "output_2" to values[2]
            )
            return mapOf(
                "status" to "technical_smoke_test_passed",
                "test_input" to "synthetic_normalized_zeros",
                "input_shape" to inputShape.toList(),
                "output_values" to values,
                "signature_output_values" to signatureValues,
                "backend_label_mapping" to mapOf(
                    "fatigue" to "output_0",
                    "heat_stress" to "output_1",
                    "physical_strain" to "output_2"
                ),
                "output_mapping_verified" to false,
                "clinical_validation" to false,
                "live_inference_enabled" to false,
                "notifications_enabled" to false
            )
        } finally {
            interpreter.close()
        }
    }
}