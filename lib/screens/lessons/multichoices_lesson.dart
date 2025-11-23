// lib/screens/lessons/multichoices_lesson.dart
import 'package:flutter/material.dart';

class MultiChoicesLesson extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onComplete;

  const MultiChoicesLesson({
    super.key,
    required this.lesson,
    required this.onComplete,
  });

  @override
  State<MultiChoicesLesson> createState() => _MultiChoicesLessonState();
}

class _MultiChoicesLessonState extends State<MultiChoicesLesson> {
  Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final options = List<String>.from(widget.lesson['options'] ?? []);
    final correctSet = Set<String>.from(widget.lesson['correctAnswers'] ?? []);

    void _checkCompletion() {
      if (_selected.length == correctSet.length && _selected.containsAll(correctSet)) {
        widget.onComplete();
      }
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lesson['question']?.toString() ?? 'Select all that apply:',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ...options.map((opt) {
            final isSelected = _selected.contains(opt);
            return CheckboxListTile(
              title: Text(opt),
              value: isSelected,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    _selected.add(opt);
                  } else {
                    _selected.remove(opt);
                  }
                });
                _checkCompletion();
              },
            );
          }).toList(),
        ],
      ),
    );
  }
}