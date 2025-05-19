import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

import '../logic/string.dart';

Future<void> updateLibraryDetails(String librarianId, Map<String, dynamic> updates) async {
  try {
    // Update in Realtime DB
    await FirebaseDatabase.instance
        .ref('${SmartLib.constPath}/librarian/$librarianId/library')
        .update(updates);

    // Update in Firestore
    await FirebaseFirestore.instance
        .collection('${SmartLib.constPath}/libraries')
        .doc(librarianId)
        .update(updates);

  } catch (e) {
    print('Error updating library: $e');
    // Add recovery logic here
  }
}