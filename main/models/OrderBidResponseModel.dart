class OrderBidResponseModel {
  final List<OrderBid>? data;
  final String? message;
  final bool? success;

  OrderBidResponseModel({this.data, this.message, this.success});

  factory OrderBidResponseModel.fromJson(Map<String, dynamic> json) {
    return OrderBidResponseModel(
      data: json['data'] != null
          ? List<OrderBid>.from(json['data'].map((x) => OrderBid.fromJson(x)))
          : null,
      message: json['message'],
      success: json['success'],
    );
  }
}

class OrderBid {
  final int? id;
  final int? orderId;
  final int? deliveryManId;
  final double? amount;
  final String? notes;
  final String? status;
  final String? createdAt;
  final String? updatedAt;

  OrderBid({
    this.id,
    this.orderId,
    this.deliveryManId,
    this.amount,
    this.notes,
    this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory OrderBid.fromJson(Map<String, dynamic> json) {
    return OrderBid(
      id: json['id'],
      orderId: json['order_id'],
      deliveryManId: json['delivery_man_id'],
      amount: json['amount']?.toDouble(),
      notes: json['notes'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}
