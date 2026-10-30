import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/errors/app_failure.dart';
import '../../../models/library_model.dart';

class LibraryPage {
  const LibraryPage({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });

  final List<LibraryModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;
}

class LibraryRepository {
  LibraryRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<LibraryPage> fetchPage({
    int pageSize = 20,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('libraries')
          .orderBy('libraryName')
          .limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final items = snapshot.docs
          .map((doc) => LibraryModel.fromMap(doc.data(), doc.id))
          .toList();

      return LibraryPage(
        items: items,
        lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == pageSize,
      );
    } on FirebaseException catch (error) {
      throw BackendFailure(error.message ?? 'Unable to load libraries.');
    } on FormatException {
      throw const DataFailure('Library data has an invalid format.');
    } catch (_) {
      throw const NetworkFailure();
    }
  }
}
