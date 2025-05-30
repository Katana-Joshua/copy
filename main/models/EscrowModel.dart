import 'package:cloud_firestore/cloud_firestore.dart';

class EscrowModel {
  String? id;
  int? orderId;
  int? clientId;
  int? deliveryManId;
  double? totalAmount;
  double? serviceCharge;
  double? pickupServiceCharge;
  double? deliveryServiceCharge;
  bool? isPickupReleased;
  bool? isDeliveryReleased;
  String? status;
  Timestamp? createdAt;
  Timestamp? updatedAt;

  EscrowModel({
    this.id,
    this.orderId,
    this.clientId,
    this.deliveryManId,
    this.totalAmount,
    this.serviceCharge,
    this.pickupServiceCharge,
    this.deliveryServiceCharge,
    this.isPickupReleased = false,
    this.isDeliveryReleased = false,
    this.status = 'pending',
    this.createdAt,
    this.updatedAt,
  });

  factory EscrowModel.fromJson(Map<String, dynamic> json) {
    return EscrowModel(
      id: json['id'],
      orderId: json['order_id'],
      clientId: json['client_id'],
      deliveryManId: json['delivery_man_id'],
      totalAmount: json['total_amount']?.toDouble(),
      serviceCharge: json['service_charge']?.toDouble(),
      pickupServiceCharge: json['pickup_service_charge']?.toDouble(),
      deliveryServiceCharge: json['delivery_service_charge']?.toDouble(),
      isPickupReleased: json['is_pickup_released'] ?? false,
      isDeliveryReleased: json['is_delivery_released'] ?? false,
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': this.id,
      'order_id': this.orderId,
      'client_id': this.clientId,
      'delivery_man_id': this.deliveryManId,
      'total_amount': this.totalAmount,
      'service_charge': this.serviceCharge,
      'pickup_service_charge': this.pickupServiceCharge,
      'delivery_service_charge': this.deliveryServiceCharge,
      'is_pickup_released': this.isPickupReleased,
      'is_delivery_released': this.isDeliveryReleased,
      'status': this.status,
      'created_at': this.createdAt,
      'updated_at': this.updatedAt,
    };
  }
}