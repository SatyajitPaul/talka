// lib/screens/lessons/explanation_lesson.dart
import 'package:flutter/material.dart';

class ExplanationLesson extends StatelessWidget {
  final Map<String, dynamic> lesson;

  const ExplanationLesson({
    super.key,
    required this.lesson,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explanation',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            lesson['content']?.toString() ?? 'Explanation content will appear here.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: const Text('Explanation marked as complete')),
              );
              // In real app: call onComplete()
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}