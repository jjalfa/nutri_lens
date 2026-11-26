import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/meal_entry.dart';
import '../models/nutrition_analysis.dart';

class FirestoreService {
  FirebaseFirestore? get _db =>
      Firebase.apps.isNotEmpty ? FirebaseFirestore.instance : null;

  CollectionReference<Map<String, dynamic>> _mealsRef(
    FirebaseFirestore db,
    String uid,
  ) {
    return db.collection('users').doc(uid).collection('meals');
  }

  Future<void> syncUserProfile(String uid) async {
    final db = _db;
    if (db == null) {
      throw StateError('Firebase no está inicializado.');
    }

    await db.collection('users').doc(uid).set({
      'plan': 'free',
      'dailyScanLimit': 3,
      'dailyCalorieGoal': 2000,
      'lastSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<MealEntry> addMeal({
    required String uid,
    required NutritionAnalysis analysis,
    DateTime? timestamp,
  }) async {
    final db = _db;
    if (db == null) {
      throw StateError('Firebase no está inicializado.');
    }

    final now = timestamp ?? DateTime.now();
    final docRef = _mealsRef(db, uid).doc();
    final entry = MealEntry(
      id: docRef.id,
      userId: uid,
      dateKey: formatDateKey(now),
      createdAt: now,
      updatedAt: now,
      analysis: analysis,
    );

    await docRef.set(entry.toFirestoreCreateMap());
    return entry;
  }

  Future<void> updateMeal({
    required String uid,
    required MealEntry existing,
    required NutritionAnalysis updatedAnalysis,
  }) async {
    final db = _db;
    if (db == null) {
      throw StateError('Firebase no está inicializado.');
    }

    final updated = existing.copyWith(
      analysis: updatedAnalysis,
      updatedAt: DateTime.now(),
    );

    await _mealsRef(db, uid)
        .doc(existing.id)
        .update(updated.toFirestoreUpdateMap());
  }

  Future<void> deleteMeal({
    required String uid,
    required String mealId,
  }) async {
    final db = _db;
    if (db == null) {
      throw StateError('Firebase no está inicializado.');
    }

    await _mealsRef(db, uid).doc(mealId).delete();
  }

  Stream<List<MealEntry>> watchMealsByDate(String uid, String dateKey) {
    final db = _db;
    if (db == null) {
      return Stream.value(const <MealEntry>[]);
    }

    return _mealsRef(db, uid)
        .where('dateKey', isEqualTo: dateKey)
        .snapshots()
        .map((snapshot) {
          final entries = <MealEntry>[];
          for (final doc in snapshot.docs) {
            try {
              entries.add(MealEntry.fromMap(doc.id, doc.data()));
            } on FormatException {
              continue;
            }
          }
          entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return entries;
        });
  }
}