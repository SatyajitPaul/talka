// lib/screens/lessons/speak_lesson.dart
import 'package:flutter/material.dart';

class SpeakLesson extends StatelessWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onComplete;

  const SpeakLesson({
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
          const Icon(Icons.mic_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            '"${lesson['text'] ?? 'Repeat after me'}"',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Simulate recording
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Recording...')),
              );
            },
            icon: const Icon(Icons.mic),
            label: const Text('Start Speaking'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onComplete,
            child: const Text('Done Speaking'),
          ),
        ],
      ),
    );
  }
}