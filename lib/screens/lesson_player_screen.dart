// lib/screens/lesson_player_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import exercise widgets
import 'lessons/description_lesson.dart';
import 'lessons/explanation_lesson.dart';
import 'lessons/selection_lesson.dart';
import 'lessons/blanks_lesson.dart';
import 'lessons/mcq_lesson.dart';
import 'lessons/multichoices_lesson.dart';
import 'lessons/match_lesson.dart';
import 'lessons/multimatch_lesson.dart';
import 'lessons/listen_lesson.dart';
import 'lessons/speak_lesson.dart';

class LessonPlayerScreen extends StatefulWidget {
  final String lessonId;
  final Color categoryColor;
  final String nativeLangCode;
  final String targetLangCode;

  const LessonPlayerScreen({
    super.key,
    required this.lessonId,
    required this.categoryColor,
    required this.nativeLangCode,
    required this.targetLangCode,
  });

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _lessonData;
  List<Map<String, dynamic>> _exercises = [];
  int _currentExerciseIndex = 0;
  Set<int> _completedExercises = {};
  bool _lessonCompleted = false;

  late AnimationController _progressController;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final doc = await FirebaseFirestore.instance
          .collection('lessons')
          .doc(widget.lessonId)
          .get();

      if (!doc.exists) {
        throw Exception('Lesson not found');
      }

      final data = doc.data()!;
      final exercises = List<Map<String, dynamic>>.from(data['exercises'] ?? []);

      // Sort exercises by order
      exercises.sort((a, b) {
        final orderA = a['order'] as int? ?? 0;
        final orderB = b['order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      setState(() {
        _lessonData = data;
        _exercises = exercises;
        _loading = false;
      });

      _slideController.forward();
      _updateProgress();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _updateProgress() {
    if (_exercises.isEmpty) return;
    final progress = (_currentExerciseIndex + 1) / _exercises.length;
    _progressController.animateTo(progress);
  }

  void _onExerciseComplete() {
    setState(() {
      _completedExercises.add(_currentExerciseIndex);
    });

    // Show celebration animation
    _showCompletionFeedback();

    // Auto-advance after a short delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _goToNext();
      }
    });
  }

  void _showCompletionFeedback() {
    final messages = [
      '🎉 Excellent!',
      '⭐ Great job!',
      '🌟 Well done!',
      '🚀 Keep it up!',
      '💪 You\'re doing great!',
    ];

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          messages[_currentExerciseIndex % messages.length],
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: widget.categoryColor,
        duration: const Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _goToNext() async {
    if (_currentExerciseIndex < _exercises.length - 1) {
      await _slideController.reverse();
      setState(() {
        _currentExerciseIndex++;
      });
      _updateProgress();
      await _slideController.forward();
    } else {
      await _completeLesson();
    }
  }

  Future<void> _goToPrevious() async {
    if (_currentExerciseIndex > 0) {
      await _slideController.reverse();
      setState(() {
        _currentExerciseIndex--;
      });
      _updateProgress();
      await _slideController.forward();
    }
  }

  Future<void> _completeLesson() async {
    setState(() {
      _lessonCompleted = true;
    });

    // Save completion to SharedPreferences
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      final completedKey = 'completed_lessons_$userId';
      final completed = Set<String>.from(prefs.getStringList(completedKey) ?? []);
      completed.add(widget.lessonId);
      await prefs.setStringList(completedKey, completed.toList());

      // Update Firestore
      try {
        await FirebaseFirestore.instance
            .collection('userProgress')
            .doc(userId)
            .set({
          'completedLessons': FieldValue.arrayUnion([widget.lessonId]),
          'lastActivityAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to update Firestore: $e');
      }
    }

    // Show completion dialog
    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildCompletionDialog(),
    );

    if (!mounted) return;
    Navigator.pop(context);
  }

  Widget _buildCompletionDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.categoryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.celebration_rounded,
                size: 64,
                color: widget.categoryColor,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Lesson Complete!',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You\'ve successfully completed this lesson. Keep up the great work!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.categoryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exitLesson() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Lesson?'),
        content: const Text('Your progress will be saved. Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Exit'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return WillPopScope(
      onWillPop: () async {
        _exitLesson();
        return false;
      },
      child: Scaffold(
        backgroundColor: colorScheme.background,
        body: _loading
            ? _buildLoadingState()
            : _error != null
            ? _buildErrorState()
            : _buildLessonContent(),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 6,
              valueColor: AlwaysStoppedAnimation<Color>(widget.categoryColor),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Preparing your lesson...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context).colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 24),
            const Text(
              'Failed to Load Lesson',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _error ?? 'Unknown error occurred',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _loadLesson,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonContent() {
    if (_exercises.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.quiz_outlined,
                size: 64,
                color: widget.categoryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'No Exercises Available',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'This lesson doesn\'t have any exercises yet.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final currentExercise = _exercises[_currentExerciseIndex];

    return Column(
      children: [
        // Custom App Bar with Progress
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _exitLesson,
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _progressController,
                        builder: (context, child) {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: _progressController.value,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.categoryColor,
                              ),
                              minHeight: 8,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_currentExerciseIndex + 1}/${_exercises.length}',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          color: widget.categoryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Exercise Content
        Expanded(
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildExerciseWidget(currentExercise),
          ),
        ),
        // Navigation Buttons
        _buildNavigationBar(),
      ],
    );
  }

  Widget _buildExerciseWidget(Map<String, dynamic> exercise) {
    final type = (exercise['type'] as String?)?.toLowerCase();

    switch (type) {
      case 'description':
        return DescriptionLesson(
          lesson: exercise,
          nativeLangCode: widget.nativeLangCode,
          targetLangCode: widget.targetLangCode,
        );
      case 'explanation':
        return ExplanationLesson(lesson: exercise);
      case 'selection':
        return SelectionLesson(
          lesson: exercise,
          onComplete: _onExerciseComplete,
        );
      case 'blanks':
        return BlanksLesson(
          lesson: exercise,
          onComplete: _onExerciseComplete,
        );
      case 'mcq':
        return MCQLesson(
          lesson: exercise,
          onComplete: _onExerciseComplete,
        );
      case 'multichoices':
        return MultiChoicesLesson(
          lesson: exercise,
          onComplete: _onExerciseComplete,
        );
      case 'match':
        return MatchLesson(
          lesson: exercise,
          onComplete: _onExerciseComplete,
        );
      case 'multimatch':
        return MultiMatchLesson(
          lesson: exercise,
          onComplete: _onExerciseComplete,
        );
      case 'listen':
        return ListenLesson(
          lesson: exercise,
          onComplete: _onExerciseComplete,
        );
      case 'speak':
        return SpeakLesson(
          lesson: exercise,
          onComplete: _onExerciseComplete,
        );
      default:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.not_interested_rounded,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Unsupported Exercise Type',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Type: $type',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
    }
  }

  Widget _buildNavigationBar() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_currentExerciseIndex > 0)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _goToPrevious,
                  icon: const Icon(Icons.arrow_back_rounded),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: widget.categoryColor,
                    side: BorderSide(color: widget.categoryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            if (_currentExerciseIndex > 0) const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _completedExercises.contains(_currentExerciseIndex)
                    ? _goToNext
                    : null,
                icon: Icon(
                  _currentExerciseIndex == _exercises.length - 1
                      ? Icons.check_rounded
                      : Icons.arrow_forward_rounded,
                ),
                label: Text(
                  _currentExerciseIndex == _exercises.length - 1
                      ? 'Finish'
                      : 'Next',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: widget.categoryColor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}