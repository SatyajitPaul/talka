// lib/utils/firestore_debug_helper.dart
// TEMPORARY DEBUG FILE - Remove after fixing the issue

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FirestoreDebugHelper {
  static Future<void> debugLessonsForCategory(String categoryId) async {
    debugPrint('=== DEBUG: Checking lessons for category: $categoryId ===');

    try {
      // Get ALL lessons without any filters
      final allLessonsSnap = await FirebaseFirestore.instance
          .collection('lessons')
          .get();

      debugPrint('Total lessons in collection: ${allLessonsSnap.docs.length}');

      // Check each lesson
      for (var doc in allLessonsSnap.docs) {
        final data = doc.data();
        debugPrint('---');
        debugPrint('Lesson ID: ${doc.id}');
        debugPrint('  categoryId: ${data['categoryId']}');
        debugPrint('  subCategoryId: ${data['subCategoryId']}');
        debugPrint('  title: ${data['title']}');
        debugPrint('  isActive: ${data['isActive']}');
        debugPrint('  order: ${data['order']}');
        debugPrint('  lessonNumber: ${data['lessonNumber']}');

        // Check if this lesson matches our category
        if (data['categoryId'] == categoryId) {
          debugPrint('  ✅ MATCHES our category!');
        }
      }

      // Now try the actual query
      debugPrint('\n=== Trying actual query ===');
      final querySnap = await FirebaseFirestore.instance
          .collection('lessons')
          .where('categoryId', isEqualTo: categoryId)
          .get();

      debugPrint('Query returned ${querySnap.docs.length} lessons');

      for (var doc in querySnap.docs) {
        debugPrint('Found lesson: ${doc.id} - ${doc.data()['title']}');
      }

    } catch (e, stackTrace) {
      debugPrint('ERROR in debug: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    debugPrint('=== END DEBUG ===\n');
  }

  static Future<void> debugCategories() async {
    debugPrint('=== DEBUG: Checking all categories ===');

    try {
      final categoriesSnap = await FirebaseFirestore.instance
          .collection('categories')
          .get();

      debugPrint('Total categories: ${categoriesSnap.docs.length}');

      for (var doc in categoriesSnap.docs) {
        final data = doc.data();
        debugPrint('---');
        debugPrint('Category ID: ${doc.id}');
        debugPrint('  name: ${data['name']}');
        debugPrint('  translations: ${data['translations']}');
        debugPrint('  isActive: ${data['isActive']}');
        debugPrint('  order: ${data['order']}');
      }
    } catch (e, stackTrace) {
      debugPrint('ERROR in category debug: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    debugPrint('=== END CATEGORY DEBUG ===\n');
  }

  static Widget buildDebugButton(BuildContext context, String categoryId) {
    return FloatingActionButton.extended(
      onPressed: () async {
        await debugCategories();
        await debugLessonsForCategory(categoryId);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debug info printed to console'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      },
      label: const Text('Debug Firestore'),
      icon: const Icon(Icons.bug_report),
      backgroundColor: Colors.orange,
    );
  }
}