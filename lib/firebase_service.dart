import 'package:cloud_firestore/cloud_firestore.dart';

class FirebaseService {
  final CollectionReference promptsCollection =
      FirebaseFirestore.instance.collection('prompts');

  Future<void> addPrompt(Map<String, dynamic> promptData) async {
    await promptsCollection.add(promptData);
  }

  Stream<QuerySnapshot> getPrompts() {
    return promptsCollection.snapshots();
  }

  Future<void> updatePrompt(String docId, Map<String, dynamic> promptData) async {
    await promptsCollection.doc(docId).update(promptData);
  }

  Future<void> deletePrompt(String docId) async {
    await promptsCollection.doc(docId).delete();
  }
}
