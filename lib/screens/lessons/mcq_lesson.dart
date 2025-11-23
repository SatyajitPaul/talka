// lib/screens/lessons/mcq_lesson.dart
import 'package:flutter/material.dart';

class MCQLesson extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onComplete;

  const MCQLesson({
    super.key,
    required this.lesson,
    required this.onComplete,
  });

  @override
  State<MCQLesson> createState() => _MCQLessonState();
}

class _MCQLessonState extends State<MCQLesson> {
  String? _selectedOption;

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(widget.lesson['options'] ?? []);
    final correctAnswer = widget.lesson['correctAnswer'] as String?;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lesson['question']?.toString() ?? 'Select the correct option:',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ...options.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              groupValue: _selectedOption,
              value: option,
              onChanged: (value) {
                setState(() {
                  _selectedOption = value;
                  if (value == correctAnswer) {
                    widget.onComplete();
                  }
                });
              },
            );
          }).toList(),
          const SizedBox(height: 16),
          if (_selectedOption != null && _selectedOption != correctAnswer)
            Text(
              'Try again!',
              style: const TextStyle(color: Colors.red),
            ),
        ],
      ),
    );
  }
}