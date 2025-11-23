// lib/screens/lessons/match_lesson.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

class MatchLesson extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onComplete;

  const MatchLesson({
    super.key,
    required this.lesson,
    required this.onComplete,
  });

  @override
  State<MatchLesson> createState() => _MatchLessonState();
}

class _MatchLessonState extends State<MatchLesson> {
  Map<String, String?> _matches = {};

  @override
  void initState() {
    super.initState();
    final pairs = List<Map<String, dynamic>>.from(widget.lesson['pairs'] ?? []);
    _matches = {for (var p in pairs) p['left'].toString(): null};
  }

  void _checkCompletion() {
    final pairs = List<Map<String, dynamic>>.from(widget.lesson['pairs'] ?? []);
    final correct = {for (var p in pairs) p['left'].toString(): p['right'].toString()};
    if (mapEquals(_matches, correct)) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pairs = List<Map<String, dynamic>>.from(widget.lesson['pairs'] ?? []);
    final leftItems = pairs.map((p) => p['left'].toString()).toList();
    final rightItems = pairs.map((p) => p['right'].toString()).toList()..shuffle();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Match the pairs:',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ...leftItems.map((left) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(left, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _matches[left],
                    hint: const Text('Select...'),
                    items: rightItems.map((r) {
                      return DropdownMenuItem(value: r, child: Text(r));
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _matches[left] = value;
                      });
                      _checkCompletion();
                    },
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}