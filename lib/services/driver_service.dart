// lib/services/driver_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Giriş yapmış şoförün drivers koleksiyonundaki dökümanını bulur.
  /// Önce uid alanına bakar → yoksa email → yoksa docId eşleşmesi.
  static Future<DocumentSnapshot?> getDriverDoc() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final col = _db.collection('drivers');

    // 1. uid alanına göre ara
    var q = await col.where('uid', isEqualTo: user.uid).limit(1).get();
    if (q.docs.isNotEmpty) return q.docs.first;

    // 2. email alanına göre ara
    if (user.email != null) {
      q = await col.where('email', isEqualTo: user.email).limit(1).get();
      if (q.docs.isNotEmpty) return q.docs.first;
    }

    // 3. döküman ID'si uid ile aynı mı?
    final doc = await col.doc(user.uid).get();
    if (doc.exists) return doc;

    return null;
  }

  /// Şoför dökümanı bulunduktan sonra uid alanını günceller (tek seferlik fix).
  static Future<void> patchUidIfMissing(DocumentSnapshot driverDoc) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final data = driverDoc.data() as Map<String, dynamic>?;
    if (data == null || data['uid'] != null) return;
    await driverDoc.reference.update({'uid': user.uid});
  }

  /// Şoför paneli için kullanılacak ana method.
  static Future<Map<String, dynamic>?> getDriverData() async {
    final doc = await getDriverDoc();
    if (doc == null) return null;
    await patchUidIfMissing(doc); // arka planda uid'yi yazar
    final data = doc.data() as Map<String, dynamic>?;
    return data != null ? {'id': doc.id, ...data} : null;
  }
}