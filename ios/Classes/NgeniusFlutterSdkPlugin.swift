import Flutter
import UIKit
import PassKit
import NISdk

public class NgeniusFlutterSdkPlugin: NSObject, FlutterPlugin, CardPaymentDelegate, ApplePayDelegate {

    private var methodChannel: FlutterMethodChannel!
    private var resultCallback: FlutterResult?
    private var paymentRequest: PKPaymentRequest?

    // MARK: - Error Enum
    enum NGeniusFlutterError: String {
        case invalidArguments = "INVALID_ARGUMENTS"
        case noRootViewController = "NO_ROOT_VIEW_CONTROLLER"
        case orderParsingFailed = "ORDER_RESPONSE_ERROR"
        case applePayFailed = "APPLE_PAY_ERROR"
        case authorizationFailed = "AUTHORIZATION_FAILED"
        case paymentFailed = "PAYMENT_FAILED"
        case unknown = "UNKNOWN_ERROR"

        func flutterError(message: String) -> FlutterError {
            return FlutterError(code: self.rawValue, message: message, details: nil)
        }
    }

    // MARK: - Register
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ngenius_flutter_sdk", binaryMessenger: registrar.messenger())
        let instance = NgeniusFlutterSdkPlugin()
        instance.methodChannel = channel
        NISdk.initialize()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    // MARK: - Handle Calls
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "launchCardPayment":
            guard let args = call.arguments as? [String: Any] else {
                result(NGeniusFlutterError.invalidArguments.flutterError(message: "Arguments are missing or invalid"))
                return
            }
            launchCardPayment(args: args, result: result)

        case "launchSavedCardPayment":
            guard let args = call.arguments as? [String: Any] else {
                result(NGeniusFlutterError.invalidArguments.flutterError(message: "Arguments are missing or invalid"))
                return
            }
            launchSavedCardPayment(args: args, result: result)

        case "launchApplePay":
            guard let args = call.arguments as? [String: Any] else {
                result(NGeniusFlutterError.invalidArguments.flutterError(message: "Arguments are missing or invalid"))
                return
            }
            launchApplePay(args: args, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - CARD PAYMENT
    private func launchCardPayment(args: [String: Any], result: @escaping FlutterResult) {
        self.resultCallback = result

        guard let orderResponseMap = args["orderJsonObject"] as? [String: Any], !orderResponseMap.isEmpty else {
            result(NGeniusFlutterError.invalidArguments.flutterError(message: "Missing orderResponse"))
            return
        }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(NGeniusFlutterError.noRootViewController.flutterError(message: "Root view controller is not available"))
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: orderResponseMap, options: [])
            let orderResponse = try JSONDecoder().decode(OrderResponse.self, from: jsonData)

            NISdk.sharedInstance.showCardPaymentViewWith(
                cardPaymentDelegate: self,
                overParent: viewController,
                for: orderResponse
            )

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.removeButtonText(from: viewController.view)
            }

        } catch let error {
            result(NGeniusFlutterError.orderParsingFailed.flutterError(message: "Failed to parse orderResponse: \(error.localizedDescription)"))
        }
    }

    // MARK: - SAVED CARD PAYMENT
    private func launchSavedCardPayment(args: [String: Any], result: @escaping FlutterResult) {
        self.resultCallback = result

        guard let orderResponseMap = args["orderJsonObject"] as? [String: Any], !orderResponseMap.isEmpty else {
            result(NGeniusFlutterError.invalidArguments.flutterError(message: "Missing orderResponse"))
            return
        }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(NGeniusFlutterError.noRootViewController.flutterError(message: "Root view controller is not available"))
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: orderResponseMap, options: [])
            let orderResponse = try JSONDecoder().decode(OrderResponse.self, from: jsonData)
            let sharedSDKInstance = NISdk.sharedInstance

            if let cvv = args["cvv"] as? String, !cvv.isEmpty {
                sharedSDKInstance.launchSavedCardPayment(
                    cardPaymentDelegate: self,
                    overParent: viewController,
                    for: orderResponse,
                    with: cvv
                )
            } else {
                sharedSDKInstance.launchSavedCardPayment(
                    cardPaymentDelegate: self,
                    overParent: viewController,
                    for: orderResponse
                )
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.removeButtonText(from: viewController.view)
            }

        } catch let error {
            result(NGeniusFlutterError.orderParsingFailed.flutterError(message: "Failed to parse orderResponse: \(error.localizedDescription)"))
        }
    }

    // MARK: - APPLE PAY
    private func launchApplePay(args: [String: Any], result: @escaping FlutterResult) {
        self.resultCallback = result

        guard let merchantId = args["merchantId"] as? String, !merchantId.isEmpty else {
            result(NGeniusFlutterError.invalidArguments.flutterError(message: "Missing merchantId"))
            return
        }

        guard let orderResponseMap = args["orderJsonObject"] as? [String: Any],
              let items = args["purchasedItems"] as? [[String: Any]],
              let paymentAmount = args["paymentAmount"] as? Double else {
            result(NGeniusFlutterError.invalidArguments.flutterError(message: "Missing Apple Pay order details or items"))
            return
        }

        guard let viewController = UIApplication.shared.keyWindow?.rootViewController else {
            result(NGeniusFlutterError.noRootViewController.flutterError(message: "Root view controller is not available"))
            return
        }

        do {
            let jsonData = try JSONSerialization.data(withJSONObject: orderResponseMap, options: [])
            let orderResponse = try JSONDecoder().decode(OrderResponse.self, from: jsonData)

            let paymentRequest = PKPaymentRequest()
            paymentRequest.merchantIdentifier = merchantId
            paymentRequest.countryCode = "AE"
            paymentRequest.currencyCode = "AED"
            paymentRequest.requiredShippingContactFields = [.postalAddress, .emailAddress, .phoneNumber]
            paymentRequest.requiredBillingContactFields = [.postalAddress, .name]
            paymentRequest.merchantCapabilities = [.capabilityDebit, .capabilityCredit, .capability3DS]

            var summaryItems: [PKPaymentSummaryItem] = []

            for item in items {
                guard let label = item["label"] as? String, let amount = item["amount"] as? Double else {
                    result(NGeniusFlutterError.invalidArguments.flutterError(message: "Invalid item format in purchasedItems"))
                    return
                }
                summaryItems.append(PKPaymentSummaryItem(label: label, amount: NSDecimalNumber(value: amount)))
            }

            summaryItems.append(PKPaymentSummaryItem(label: "Total", amount: NSDecimalNumber(value: paymentAmount)))
            paymentRequest.paymentSummaryItems = summaryItems
            self.paymentRequest = paymentRequest

            NISdk.sharedInstance.initiateApplePayWith(
                applePayDelegate: self,
                cardPaymentDelegate: self,
                overParent: viewController,
                for: orderResponse,
                with: paymentRequest
            )

        } catch let error {
            result(NGeniusFlutterError.applePayFailed.flutterError(message: "Apple Pay initialization failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - UI FIX
    private func removeButtonText(from view: UIView) {
        let allButtons = view.subviews.compactMap { $0 as? UIButton }
        for button in allButtons {
            if let title = button.title(for: .normal), title.contains("0") {
                button.setTitle("Pay", for: .normal)
                button.setImage(nil, for: .normal)
            }
        }
    }

    // MARK: - DELEGATES
    public func paymentDidComplete(with status: PaymentStatus) {
        var resultDict: [String: Any]
        switch status {
        case .PaymentSuccess:
            resultDict = ["code": 200, "status": "success", "reason": "PAYMENT_SUCCESSFUL", "result": "success"]
        case .PaymentFailed:
            resultDict = ["code": 0, "status": "failed", "reason": "PAYMENT_FAILED", "result": "failed"]
        case .PaymentCancelled:
            resultDict = ["code": 401, "status": "canceled", "reason": "CANCELLED_BY_USER", "result": "canceled"]
        @unknown default:
            resultDict = ["code": -1, "status": "unknown", "reason": "UNKNOWN_ERROR", "result": "unknown"]
        }

        sendResult(resultDict)
    }

    public func authorizationDidComplete(with status: AuthorizationStatus) {
        if status == .AuthFailed {
            let resultDict: [String: Any] = [
                "code": -1,
                "status": "failed",
                "reason": "AUTHORIZATION_FAILED",
                "result": "auth_failed"
            ]
            sendResult(resultDict)
        }
    }

    // MARK: - HELPER
    private func sendResult(_ dict: [String: Any]) {
        if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
           let jsonString = String(data: jsonData, encoding: .utf8),
           let resultCallback = self.resultCallback {
            resultCallback(jsonString)
            self.resultCallback = nil
        }
    }
}
