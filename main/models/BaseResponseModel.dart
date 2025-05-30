class BaseResponseModel {
  final String? message;
  final bool? success;

  BaseResponseModel({this.message, this.success});

  factory BaseResponseModel.fromJson(Map<String, dynamic> json) {
    return BaseResponseModel(
      message: json['message'],
      success: json['success'],
    );
  }
}
