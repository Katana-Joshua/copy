import 'package:cloud_firestore/cloud_firestore.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../main.dart';
import '../../main/models/EscrowModel.dart';
import '../../main/utils/Constants.dart';
import 'BaseServices.dart';

class EscrowService extends BaseService {
  FirebaseFirestore fireStore = FirebaseFirestore.instance;

  EscrowService() {
    ref = fireStore.collection(ESCROW_COLLECTION);
  }

  Future<DocumentReference> createEscrow(EscrowModel data) async {
    var doc = await ref!.add(data.toJson());
    doc.update({'id': doc.id});
    return doc;
  }

  Future<void> updateEscrow(String id, Map<String, dynamic> data) async {
    return ref!.doc(id).update(data);
  }

  Future<EscrowModel?> getEscrowByOrderId(int orderId) async {
    QuerySnapshot snapshot = await ref!.where('order_id', isEqualTo: orderId).get();
    
    if (snapshot.docs.isNotEmpty) {
      return EscrowModel.fromJson(snapshot.docs.first.data() as Map<String, dynamic>);
    }
    
    return null;
  }

  Future<void> releasePickupServiceCharge(int orderId) async {
    EscrowModel? escrow = await getEscrowByOrderId(orderId);
    
    if (escrow != null && !escrow.isPickupReleased!) {
      // Update escrow record
      await updateEscrow(escrow.id!, {
        'is_pickup_released': true,
        'updated_at': Timestamp.now(),
      });
      
      // Add to delivery man's wallet
      await addToDeliveryManWallet(
        escrow.deliveryManId!,
        escrow.pickupServiceCharge!,
        orderId,
        TRANSACTION_PICKUP_SERVICE_CHARGE
      );
    }
  }

  Future<void> releaseDeliveryServiceCharge(int orderId) async {
    EscrowModel? escrow = await getEscrowByOrderId(orderId);
    
    if (escrow != null && !escrow.isDeliveryReleased!) {
      // Update escrow record
      await updateEscrow(escrow.id!, {
        'is_delivery_released': true,
        'status': 'completed',
        'updated_at': Timestamp.now(),
      });
      
      // Add to delivery man's wallet
      await addToDeliveryManWallet(
        escrow.deliveryManId!,
        escrow.deliveryServiceCharge!,
        orderId,
        TRANSACTION_DELIVERY_SERVICE_CHARGE
      );
    }
  }

  Future<void> addToDeliveryManWallet(int deliveryManId, double amount, int orderId, String transactionType) async {
    // Add transaction to wallet collection
    await fireStore.collection(WALLET_COLLECTION).add({
      'user_id': deliveryManId,
      'amount': amount,
      'order_id': orderId,
      'transaction_type': transactionType,
      'type': CREDIT,
      'created_at': Timestamp.now(),
    });
    
    log("Added $amount to delivery man $deliveryManId's wallet for order $orderId");
  }

  Future<void> deductFromClientWallet(int clientId, double amount, int orderId) async {
    // Add transaction to wallet collection
    await fireStore.collection(WALLET_COLLECTION).add({
      'user_id': clientId,
      'amount': amount,
      'order_id': orderId,
      'transaction_type': TRANSACTION_SERVICE_CHARGE,
      'type': DEBIT,
      'created_at': Timestamp.now(),
    });
    
    log("Deducted $amount from client $clientId's wallet for order $orderId");
  }
}