// lib/screens/lessons/listen_lesson.dart
import 'package:flutter/material.dart';

class ListenLesson extends StatelessWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onComplete;

  const ListenLesson({
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
          const Icon(Icons.headphones_outlined, size: 64),
          const SizedBox(height: 16),
          const Text('Listen to the audio (placeholder)'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Simulate play
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Playing audio...')),
              );
            },
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Audio'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onComplete,
            child: const Text('I Listened'),
          ),
        ],
      ),
    );
  }
}