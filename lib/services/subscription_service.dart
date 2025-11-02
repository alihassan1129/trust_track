import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubscriptionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Subscribe the current user to a policy
  Future<void> subscribeToPolicy(
    String policyId,
    String policyName,
    double amount,
    String paymentCycle,
  ) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in.");

    final startDate = DateTime.now();
    final nextDueDate = paymentCycle.toLowerCase() == "monthly"
        ? DateTime(startDate.year, startDate.month + 1, startDate.day)
        : DateTime(startDate.year + 1, startDate.month, startDate.day);

    await _firestore.collection("subscriptions").add({
      "userId": user.uid,
      "policyId": policyId,
      "policyName": policyName,
      "amount": amount,
      "paymentCycle": paymentCycle,
      "startDate": startDate,
      "nextDueDate": nextDueDate,
      "status": "active",
      "createdAt": FieldValue.serverTimestamp(),
    });

    final userPolicyRef = _firestore
        .collection("user_policies")
        .doc("${user.uid}_$policyId");

    await userPolicyRef.set({
      "userId": user.uid,
      "policyId": policyId,
      "isSubscribed": true,
      "paid": true,
      "timestamp": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get all subscriptions of a user
  Future<List<Map<String, dynamic>>> getUserSubscriptions() async {
  final user = _auth.currentUser;
  if (user == null) return [];

  final snapshot = await _firestore
      .collection("subscriptions")
      .where("userId", isEqualTo: user.uid)
      .where("status", isEqualTo: "active") // only active subscriptions
      .get();

  return snapshot.docs
      .map((d) => {"id": d.id, ...d.data() as Map<String, dynamic>})
      .toList();
}

  /// Unsubscribe or cancel a policy
  Future<void> unsubscribe(String subscriptionId) async {
    await _firestore.collection("subscriptions").doc(subscriptionId).update({
      "status": "unsubscribed",
    });
  }

  Future<List<DateTime>> getSubscriptionHistory(
    String userId,
    String policyId,
  ) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('subscriptions')
          .where('userId', isEqualTo: userId)
          .where('policyId', isEqualTo: policyId)
          .orderBy('startDate', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => (doc['startDate'] as Timestamp).toDate())
          .toList();
    } catch (e) {
      debugPrint("Error loading history for $policyId: $e");
      return [];
    }
  }
}
