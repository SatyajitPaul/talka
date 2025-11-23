// lib/screens/lessons/multimatch_lesson.dart
import 'package:flutter/material.dart';

class MultiMatchLesson extends StatelessWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onComplete;

  const MultiMatchLesson({
    super.key,
    required this.lesson,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.ac_unit_rounded, size: 64),
          const SizedBox(height: 16),
          const Text('Multi-match lesson (placeholder)'),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onComplete,
            child: const Text('Mark as Complete'),
          ),
        ],
      ),
    );
  }
}