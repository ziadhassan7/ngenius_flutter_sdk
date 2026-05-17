import 'package:ngenius_flutter_sdk/models/ngenius_response_model.dart';

import 'ngenius_flutter_sdk_platform_interface.dart';

class NgeniusFlutterSdk {
  Future<NGeniusResponseModel> launchCardPayment(
      {required Map<String, dynamic> orderJsonObject}) {
    return NgeniusFlutterSdkPlatform.instance
        .launchCardPayment(orderJsonObject: orderJsonObject);
  }

  Future<NGeniusResponseModel> launchSavedCardPayment({
    required Map<String, dynamic> orderJsonObject,
    String? cvv,
  }) {
    return NgeniusFlutterSdkPlatform.instance
        .launchSavedCardPayment(orderJsonObject: orderJsonObject, cvv: cvv);
  }

  Future<NGeniusResponseModel> launchApplePay({
    required String merchantId,
    required Map<String, dynamic> orderJsonObject,
    required List<Map<String, dynamic>> purchasedItems,
    required double paymentAmount,
  }) {
    return NgeniusFlutterSdkPlatform.instance.launchApplePay(
      merchantId: merchantId,
      orderJsonObject: orderJsonObject,
      purchasedItems: purchasedItems,
      paymentAmount: paymentAmount,
    );
  }

  Future<NGeniusResponseModel> launchGooglePay({
    required String merchantGatewayId,
    required Map<String, dynamic> orderJsonObject,
  }) {
    return NgeniusFlutterSdkPlatform.instance.launchGooglePay(
      merchantGatewayId: merchantGatewayId,
      orderJsonObject: orderJsonObject,
    );
  }

}
