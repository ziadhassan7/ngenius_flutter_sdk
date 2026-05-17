
class NGeniusResponseModel{
  int? code;
  String? message;

  NGeniusResponseModel({this.code, this.message});

  NGeniusResponseModel.fromJson({required Map<String, dynamic> json}) {
    code = json['code'];
    message = json['reason'];
  }
}