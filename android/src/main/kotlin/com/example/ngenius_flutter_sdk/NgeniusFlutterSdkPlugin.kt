package com.example.ngenius_flutter_sdk

import androidx.activity.ComponentActivity
import androidx.fragment.app.FragmentActivity
import android.app.Activity
import android.content.Intent
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry.ActivityResultListener
import payment.sdk.android.PaymentClient
import payment.sdk.android.cardpayment.CardPaymentData
import payment.sdk.android.cardpayment.CardPaymentRequest
import payment.sdk.android.core.Order
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.util.HashMap
import com.google.gson.Gson

import payment.sdk.android.googlepay.GooglePayConfig
import payment.sdk.android.payments.PaymentsLauncher
import payment.sdk.android.payments.PaymentsRequest
import payment.sdk.android.payments.PaymentsResult



/** NgeniusFlutterSdkPlugin */
class NgeniusFlutterSdkPlugin: FlutterPlugin, MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {

  private lateinit var channel : MethodChannel
  private lateinit var paymentClient: PaymentClient
  private var activity: Activity? = null
  private var pendingResult: Result? = null
  private lateinit var paymentsLauncher: PaymentsLauncher

  companion object {
    private const val CARD_PAYMENT_REQUEST_CODE = 123
  }

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ngenius_flutter_sdk")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {

      // ===========================
      // Standard Payment
      // ===========================
      "launchCardPayment" -> {
        try {
          val jsonData = call.argument<HashMap<String, Any>>("orderJsonObject")
            ?: throw IllegalArgumentException("orderJsonObject is required")

          val links = jsonData["_links"] as? HashMap<String, Any>
            ?: throw Exception("_links not found in orderJsonObject")

          val authUrl = ((links["payment-authorization"] as? HashMap<String, Any>)?.get("href") as? String)
            ?: throw Exception("Authorization URL not found in orderJsonObject")

          val paymentUrl = ((links["payment"] as? HashMap<String, Any>)?.get("href") as? String)
            ?: throw Exception("Payment URL not found in orderJsonObject")

          val code = if (paymentUrl.contains("code=")) {
            paymentUrl.substringAfter("code=").takeIf { it.isNotEmpty() }
              ?: throw Exception("Code value is empty in orderJsonObject")
          } else {
            throw Exception("Code parameter not found in payment URL")
          }

          pendingResult = result
          activity?.let { currentActivity ->
            paymentClient = PaymentClient(currentActivity, "DEMO_VAL")
            paymentClient.launchCardPayment(
              CardPaymentRequest.Builder()
                .gatewayUrl(authUrl)
                .code(code)
                .build(),
              CARD_PAYMENT_REQUEST_CODE
            )
          } ?: result.error("NO_ACTIVITY", "No activity available", null)
        } catch (e: Exception) {
          result.error("LAUNCH_ERROR", e.message ?: "Unknown error occurred", null)
        }
      }

      // ===========================
      // Saved Card Payment
      // ===========================
      "launchSavedCardPayment" -> {
        try {
          val jsonData = call.argument<HashMap<String, Any>>("orderJsonObject")
            ?: throw IllegalArgumentException("orderJsonObject is required")


          // Convert to JSON string, then to Order object
          val orderJson = JSONObject(jsonData as Map<*, *>).toString()
          val order = Gson().fromJson(orderJson, Order::class.java)

          val cvv = call.argument<String>("cvv") // May be null or empty

          pendingResult = result
          activity?.let { currentActivity ->
            paymentClient = PaymentClient(currentActivity, "YOUR_SERVICE_ID")

            if (!cvv.isNullOrEmpty()) {
              // Option 2: Launch with custom CVV, skipping the pay page
              paymentClient.launchSavedCardPayment(
                order = order,
                cvv = cvv,
                code = CARD_PAYMENT_REQUEST_CODE
              )
            } else {
              // Option 1: Launch without CVV. This will redirect to the pay page if 'recaptureCsc' was true in the order.
              paymentClient.launchSavedCardPayment(
                order = order,
                code = CARD_PAYMENT_REQUEST_CODE
              )
            }
          } ?: result.error("NO_ACTIVITY", "No activity available", null)

        } catch (e: Exception) {
          result.error("SAVED_CARD_ERROR", e.message ?: "Unknown error occurred", null)
        }
      }


      // ===========================
      // Google Pay Implementation
      // ===========================
      "launchGooglePay" -> {
        try {
          // 1. Get required arguments from Flutter
          val jsonData = call.argument<HashMap<String, Any>>("orderJsonObject")
            ?: throw IllegalArgumentException("orderJsonObject is required")

          val links = jsonData["_links"] as? HashMap<String, Any>
            ?: throw Exception("_links not found in orderJsonObject")

          val authUrl = ((links["payment-authorization"] as? HashMap<String, Any>)?.get("href") as? String)
            ?: throw Exception("Authorization URL not found in orderJsonObject")

          val paymentUrl = ((links["payment"] as? HashMap<String, Any>)?.get("href") as? String)
            ?: throw Exception("Payment URL not found in orderJsonObject")

          val merchantGatewayId = call.argument<String>("merchantGatewayId")
            ?: throw IllegalArgumentException("Merchant Gateway ID is required")

          // 2. Create GooglePayConfig using the constructor
          val googlePayConfig = GooglePayConfig(
            environment = GooglePayConfig.Environment.Test, // or .Production
            merchantGatewayId = merchantGatewayId
          )

          // 3. Build PaymentsRequest
          val paymentsRequest = PaymentsRequest.builder()
            .gatewayAuthorizationUrl(authUrl)
            .payPageUrl(paymentUrl)
            .setGooglePayConfig(googlePayConfig)
            .build()

          // 4. Create PaymentsLauncher and launch
          pendingResult = result
          paymentsLauncher.launch(paymentsRequest)

        } catch (e: Exception) {
          result.error("GOOGLE_PAY_ERROR", e.message ?: "Unknown error occurred during Google Pay launch", null)
        }
      }


      else -> result.notImplemented()
    }
  }


  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }


  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    activity = binding.activity

    // Initialize PaymentsLauncher (for Google Pay)
    val componentActivity = activity as? ComponentActivity
      ?: throw IllegalStateException("Activity must be a ComponentActivity." +
              " in Flutter in your MainActivity extend FlutterFragmentActivity")

    paymentsLauncher = PaymentsLauncher(componentActivity) { paymentsResult ->
      handlePaymentResult(paymentsResult)
    }

    binding.addActivityResultListener(this)
  }

  override fun onDetachedFromActivity() {
    activity = null
  }

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    onAttachedToActivity(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {
    onDetachedFromActivity()
  }

  private fun handlePaymentResult(paymentsResult: PaymentsResult) {
    val ngeniusResponse = when (paymentsResult) {
      is PaymentsResult.Success -> mapOf(
        "code" to 200, //"PAYMENT_SUCCESSFUL",
        "reason" to "Payment completed successfully"
      )
      is PaymentsResult.Authorised -> mapOf(
        "code" to 201, //"PAYMENT_AUTHORISED",
        "reason" to "Payment authorised successfully"
      )
      is PaymentsResult.PostAuthReview -> mapOf(
        "code" to 203, //"POST_AUTH_REVIEW",
        "reason" to "Payment requires post-authorization review"
      )
      is PaymentsResult.PartialAuthDeclined -> mapOf(
        "code" to 204, //"PARTIAL_AUTH_DECLINED",
        "reason" to "Partial authorization was declined"
      )
      is PaymentsResult.PartialAuthDeclineFailed -> mapOf(
        "code" to 205, //"PARTIAL_AUTH_DECLINE_FAILED",
        "reason" to "Partial authorization reversal failed"
      )
      is PaymentsResult.PartiallyAuthorised -> mapOf(
        "code" to 206, //"PARTIALLY_AUTHORISED",
        "reason" to "Payment partially authorised"
      )
      is PaymentsResult.Failed -> mapOf(
        "code" to 400, //"PAYMENT_FAILED",
        "reason" to paymentsResult.error
      )
      is PaymentsResult.Cancelled -> mapOf(
        "code" to 401, //"CANCELLED_BY_USER",
        "reason" to "User cancelled the payment"
      )
    }

    val jsonString = JSONObject(ngeniusResponse).toString()
    pendingResult?.success(jsonString)
    pendingResult = null
  }


  @Override
  override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
    return if (requestCode == CARD_PAYMENT_REQUEST_CODE) {
      when (resultCode) {
        Activity.RESULT_OK -> {
          if(data != null){
            val cardPaymentData = CardPaymentData.getFromIntent(data)
            cardPaymentData?.let {
              val resultMessage = when (it.code) {
                CardPaymentData.STATUS_PAYMENT_AUTHORIZED,
                CardPaymentData.STATUS_PAYMENT_CAPTURED,
                CardPaymentData.STATUS_POST_AUTH_REVIEW,
                CardPaymentData.STATUS_PAYMENT_PURCHASED -> "PAYMENT_SUCCESSFUL"

                CardPaymentData.STATUS_PAYMENT_FAILED -> "STATUS_PAYMENT_FAILED"
                CardPaymentData.STATUS_GENERIC_ERROR -> "STATUS_GENERIC_ERROR"
                else -> "Unknown payment response: ${it.reason}"
              }
              val ngeniusResponse = mapOf(
                "code" to cardPaymentData.code,
                "reason" to resultMessage,
              )
              val jsonString = org.json.JSONObject(ngeniusResponse).toString()
              pendingResult?.success(jsonString)
            }
          }
        }
        Activity.RESULT_CANCELED -> {
          val cancelMap = mapOf(
            "code" to 401,
            "reason" to "CANCELLED_BY_USER",
          )
          val jsonString = org.json.JSONObject(cancelMap).toString()
          pendingResult?.success(jsonString)
        }
      }
      true
    } else {
      false
    }
  }

}