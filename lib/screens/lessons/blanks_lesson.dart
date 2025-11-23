// lib/screens/lessons/blanks_lesson.dart
import 'package:flutter/material.dart';

class BlanksLesson extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final VoidCallback onComplete;

  const BlanksLesson({
    super.key,
    required this.lesson,
    required this.onComplete,
  });

  @override
  State<BlanksLesson> createState() => _BlanksLessonState();
}

class _BlanksLessonState extends State<BlanksLesson> {
  final TextEditingController _controller = TextEditingController();
  bool _isCorrect = false;
  bool _submitted = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    final userAnswer = _controller.text.trim().toLowerCase();
    final correctAnswers = List<String>.from(widget.lesson['answers'] ?? [])
        .map((a) => a.toString().toLowerCase())
        .toList();

    final correct = correctAnswers.contains(userAnswer);
    setState(() {
      _submitted = true;
      _isCorrect = correct;
    });

    if (correct) {
      widget.onComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.lesson['prompt']?.toString() ?? 'Fill in the blank:',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              border: const OutlineInputBorder(),
              suffixIcon: _submitted
                  ? Icon(
                _isCorrect ? Icons.check_circle : Icons.error,
                color: _isCorrect ? Colors.green : Colors.red,
              )
                  : null,
            ),
            enabled: !_submitted,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitted ? null : _checkAnswer,
            child: const Text('Submit'),
          ),
          if (_submitted && !_isCorrect)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Incorrect. Try again!',
                style: const TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }
}