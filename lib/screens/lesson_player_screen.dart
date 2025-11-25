// lib/screens/lesson_player_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import all lesson/exercise screens
import 'lessons/lesson_introduction_screen.dart';
import 'lessons/introduction_exercise_screen.dart';
import 'lessons/cultural_notes_screen.dart';
import 'lessons/focus_sentences_screen.dart';
import 'lessons/lesson_summary_screen.dart';

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

  // Content items to display
  List<Map<String, dynamic>> _contentItems = [];
  int _currentIndex = 0;
  Set<int> _completedIndices = {};

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

      // Build content flow
      _buildContentFlow(data);

      setState(() {
        _lessonData = data;
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

  void _buildContentFlow(Map<String, dynamic> lessonData) {
    final items = <Map<String, dynamic>>[];

    // 1. Lesson Introduction
    items.add({
      'type': 'lesson_intro',
      'data': lessonData,
    });

    // 2. Get exercises and cultural notes
    final exercises = List<Map<String, dynamic>>.from(
      lessonData['exercises'] ?? [],
    );
    final culturalNotes = List<Map<String, dynamic>>.from(
      lessonData['culturalNotes'] ?? [],
    );

    // Sort exercises by order
    exercises.sort((a, b) {
      final orderA = a['order'] as int? ?? 0;
      final orderB = b['order'] as int? ?? 0;
      return orderA.compareTo(orderB);
    });

    // Sort cultural notes by order
    culturalNotes.sort((a, b) {
      final orderA = a['order'] as int? ?? 0;
      final orderB = b['order'] as int? ?? 0;
      return orderA.compareTo(orderB);
    });

    // 3. Interleave exercises with cultural notes
    for (int i = 0; i < exercises.length; i++) {
      // Add exercise
      items.add({
        'type': 'exercise',
        'data': exercises[i],
      });

      // Check if there's a cultural note to display after this exercise
      for (var note in culturalNotes) {
        final displayAfter = note['displayAfterExercise'] as int? ?? -1;
        final isActive = note['isActive'] as bool? ?? true;

        if (isActive && displayAfter == i) {
          items.add({
            'type': 'cultural_note',
            'data': note,
          });
        }
      }
    }

    // 4. Focus Sentences (if available)
    final focusSentences = List<Map<String, dynamic>>.from(
      lessonData['focusSentences'] ?? [],
    );
    if (focusSentences.isNotEmpty) {
      // Sort by order
      focusSentences.sort((a, b) {
        final orderA = a['order'] as int? ?? 0;
        final orderB = b['order'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      // Filter active sentences
      final activeSentences = focusSentences
          .where((s) => s['isActive'] as bool? ?? true)
          .toList();

      if (activeSentences.isNotEmpty) {
        items.add({
          'type': 'focus_sentences',
          'data': activeSentences,
        });
      }
    }

    // 5. Lesson Summary
    items.add({
      'type': 'lesson_summary',
      'data': lessonData,
    });

    _contentItems = items;
  }

  void _updateProgress() {
    if (_contentItems.isEmpty) return;
    final progress = (_currentIndex + 1) / _contentItems.length;
    _progressController.animateTo(progress);
  }

  void _onItemComplete() {
    setState(() {
      _completedIndices.add(_currentIndex);
    });

    // Auto-advance with a small delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _goToNext();
      }
    });
  }

  Future<void> _goToNext() async {
    if (_currentIndex < _contentItems.length - 1) {
      await _slideController.reverse();
      setState(() {
        _currentIndex++;
      });
      _updateProgress();
      await _slideController.forward();
    } else {
      // Lesson completed
      await _completeLesson();
    }
  }

  Future<void> _goToPrevious() async {
    if (_currentIndex > 0) {
      await _slideController.reverse();
      setState(() {
        _currentIndex--;
      });
      _updateProgress();
      await _slideController.forward();
    }
  }

  Future<void> _completeLesson() async {
    // Save completion
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId != null) {
      final prefs = await SharedPreferences.getInstance();
      final completedKey = 'completed_lessons_$userId';
      final completed = Set<String>.from(
        prefs.getStringList(completedKey) ?? [],
      );
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

    // Navigate back
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _exitLesson() async {
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Exit Lesson?'),
        content: const Text(
          'Your progress will be saved. Are you sure you want to exit?',
        ),
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
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.categoryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Preparing your lesson...',
            style: TextStyle(
              fontSize: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onBackground
                  .withOpacity(0.7),
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
                color: Theme.of(context)
                    .colorScheme
                    .onBackground
                    .withOpacity(0.6),
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
    if (_contentItems.isEmpty) {
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
                'No Content Available',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentItem = _contentItems[_currentIndex];
    final itemType = currentItem['type'] as String;

    // For intro and summary, we don't show progress bar and navigation
    final showNavigation = itemType != 'lesson_intro' &&
        itemType != 'lesson_summary';

    return Column(
      children: [
        // Progress Bar (only if not intro or summary)
        if (showNavigation)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
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
                      '${_currentIndex + 1}/${_contentItems.length}',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: widget.categoryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Content
        Expanded(
          child: SlideTransition(
            position: _slideAnimation,
            child: _buildContentWidget(currentItem),
          ),
        ),

        // Navigation Buttons (only for exercises)
        if (showNavigation && itemType == 'exercise')
          _buildNavigationBar(),
      ],
    );
  }

  Widget _buildContentWidget(Map<String, dynamic> item) {
    final type = item['type'] as String;
    final data = item['data'];

    switch (type) {
      case 'lesson_intro':
        return LessonIntroductionScreen(
          lessonData: data,
          categoryColor: widget.categoryColor,
          nativeLangCode: widget.nativeLangCode,
          onContinue: _onItemComplete,
        );

      case 'cultural_note':
        return CulturalNotesScreen(
          culturalNote: data,
          categoryColor: widget.categoryColor,
          onContinue: _onItemComplete,
        );

      case 'focus_sentences':
        return FocusSentencesScreen(
          focusSentences: data,
          categoryColor: widget.categoryColor,
          onContinue: _onItemComplete,
        );

      case 'lesson_summary':
        final exerciseCount = _contentItems
            .where((item) => item['type'] == 'exercise')
            .length;
        return LessonSummaryScreen(
          lessonData: _lessonData!,
          categoryColor: widget.categoryColor,
          exercisesCompleted: exerciseCount,
          nativeLangCode: widget.nativeLangCode,
          onFinish: _completeLesson,
        );

      case 'exercise':
        return _buildExerciseWidget(data);

      default:
        return Center(
          child: Text('Unknown content type: $type'),
        );
    }
  }

  Widget _buildExerciseWidget(Map<String, dynamic> exercise) {
    final exerciseType = (exercise['type'] as String?)?.toLowerCase();

    switch (exerciseType) {
      case 'introduction':
        return IntroductionExerciseScreen(
          exercise: exercise,
          categoryColor: widget.categoryColor,
          onComplete: _onItemComplete,
        );

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
          onComplete: _onItemComplete,
        );

      case 'blanks':
        return BlanksLesson(
          lesson: exercise,
          onComplete: _onItemComplete,
        );

      case 'mcq':
        return MCQLesson(
          lesson: exercise,
          onComplete: _onItemComplete,
        );

      case 'multichoices':
        return MultiChoicesLesson(
          lesson: exercise,
          onComplete: _onItemComplete,
        );

      case 'match':
        return MatchLesson(
          lesson: exercise,
          onComplete: _onItemComplete,
        );

      case 'multimatch':
        return MultiMatchLesson(
          lesson: exercise,
          onComplete: _onItemComplete,
        );

      case 'listen':
        return ListenLesson(
          lesson: exercise,
          onComplete: _onItemComplete,
        );

      case 'speak':
        return SpeakLesson(
          lesson: exercise,
          onComplete: _onItemComplete,
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
                  'Type: $exerciseType',
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
    final canGoNext = _completedIndices.contains(_currentIndex);

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
            if (_currentIndex > 0 &&
                _contentItems[_currentIndex]['type'] == 'exercise')
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
            if (_currentIndex > 0 &&
                _contentItems[_currentIndex]['type'] == 'exercise')
              const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: canGoNext ? _goToNext : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text(
                  'Next',
                  style: TextStyle(
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