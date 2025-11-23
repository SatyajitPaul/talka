// lib/screens/lessons/selection_lesson.dart
import 'package:flutter/material.dart';

class SelectionLesson extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onComplete;

  const SelectionLesson({
    super.key,
    required this.lesson,
    required this.onComplete,
  });

  @override
  State<SelectionLesson> createState() => _SelectionLessonState();
}

class _SelectionLessonState extends State<SelectionLesson> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(widget.lesson['options'] ?? []);
    final correct = widget.lesson['correctAnswer'] as String?;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lesson['prompt']?.toString() ?? 'Select the correct option:',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ...options.map((opt) {
            return RadioListTile<String>(
              title: Text(opt),
              value: opt,
              groupValue: _selected,
              onChanged: (value) {
                setState(() => _selected = value);
                if (value == correct) {
                  widget.onComplete();
                }
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}