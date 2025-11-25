// lib/screens/category_lessons_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;
import 'lesson_player_screen.dart';

// TEMPORARY - for debugging
import '../utils/firestore_debug_helper.dart';

class CategoryLessonsScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final Color categoryColor;
  final IconData categoryIcon;
  final String nativeLangCode;
  final String targetLangCode;

  const CategoryLessonsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.nativeLangCode,
    required this.targetLangCode,
  });

  @override
  State<CategoryLessonsScreen> createState() => _CategoryLessonsScreenState();
}

class _CategoryLessonsScreenState extends State<CategoryLessonsScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _lessons = [];
  Set<String> _completedLessonIds = {};
  late AnimationController _headerController;
  late Animation<double> _headerAnimation;

  @override
  void initState() {
    super.initState();
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await Future.wait([
        _loadLessons(),
        _loadCompletedLessons(),
      ]);
      _headerController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _loadLessons() async {
    try {
      // First, try with isActive filter and order
      var query = FirebaseFirestore.instance
          .collection('lessons')
          .where('categoryId', isEqualTo: widget.categoryId);

      // Try to add isActive filter if the field exists
      try {
        query = query.where('isActive', isEqualTo: true);
      } catch (e) {
        debugPrint('isActive field might not exist: $e');
      }

      final snap = await query.get();

      var lessons = snap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();

      // Sort by order field if it exists
      lessons.sort((a, b) {
        final orderA = a['order'] as int? ?? a['lessonNumber'] as int? ?? 0;
        final orderB = b['order'] as int? ?? b['lessonNumber'] as int? ?? 0;
        return orderA.compareTo(orderB);
      });

      setState(() {
        _lessons = lessons;
      });

      debugPrint('Loaded ${lessons.length} lessons for category ${widget.categoryId}');
    } catch (e) {
      debugPrint('Error loading lessons: $e');
      // Try without isActive filter
      try {
        final snap = await FirebaseFirestore.instance
            .collection('lessons')
            .where('categoryId', isEqualTo: widget.categoryId)
            .get();

        var lessons = snap.docs
            .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
            .toList();

        lessons.sort((a, b) {
          final orderA = a['order'] as int? ?? a['lessonNumber'] as int? ?? 0;
          final orderB = b['order'] as int? ?? b['lessonNumber'] as int? ?? 0;
          return orderA.compareTo(orderB);
        });

        setState(() {
          _lessons = lessons;
        });

        debugPrint('Loaded ${lessons.length} lessons (without isActive filter)');
      } catch (e2) {
        debugPrint('Error loading lessons without filter: $e2');
        throw e2;
      }
    }
  }

  Future<void> _loadCompletedLessons() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final completedKey = 'completed_lessons_$userId';
    final completedList = prefs.getStringList(completedKey) ?? [];

    setState(() {
      _completedLessonIds = Set<String>.from(completedList);
    });
  }

  String _getLocalizedTitle(Map<String, dynamic> lesson) {
    try {
      final title = lesson['title'];
      if (title is Map) {
        return (title[widget.nativeLangCode] ?? title.values.first ?? '')
            .toString();
      }
      return title?.toString() ?? 'Untitled Lesson';
    } catch (_) {
      return 'Untitled Lesson';
    }
  }

  String _getLocalizedDescription(Map<String, dynamic> lesson) {
    try {
      final desc = lesson['description'];
      if (desc is Map) {
        return (desc[widget.nativeLangCode] ?? desc.values.first ?? '')
            .toString();
      }
      return desc?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _getLevelLabel(String? level) {
    switch (level?.toLowerCase()) {
      case 'beginner':
        return 'Beginner';
      case 'intermediate':
        return 'Intermediate';
      case 'advanced':
        return 'Advanced';
      default:
        return 'All Levels';
    }
  }

  Color _getLevelColor(String? level) {
    switch (level?.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return Colors.orange;
      case 'advanced':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }

  IconData _getLessonIcon(int index) {
    final icons = [
      Icons.star_rounded,
      Icons.bolt_rounded,
      Icons.diamond_rounded,
      Icons.whatshot_rounded,
      Icons.celebration_rounded,
      Icons.military_tech_rounded,
    ];
    return icons[index % icons.length];
  }

  int _getCompletedCount() {
    return _lessons.where((l) => _completedLessonIds.contains(l['id'])).length;
  }

  int _getProgressPercentage() {
    if (_lessons.isEmpty) return 0;
    return ((_getCompletedCount() / _lessons.length) * 100).round();
  }

  bool _isLessonUnlocked(int index) {
    // First lesson is always unlocked
    if (index == 0) return true;

    // Check if previous lesson is completed
    if (index > 0 && index < _lessons.length) {
      final previousLesson = _lessons[index - 1];
      return _completedLessonIds.contains(previousLesson['id']);
    }

    return false;
  }

  @override
  void dispose() {
    _headerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final completedCount = _getCompletedCount();
    final progress = _getProgressPercentage();

    return Scaffold(
      backgroundColor: colorScheme.background,
      // TEMPORARY DEBUG BUTTON
      floatingActionButton: FirestoreDebugHelper.buildDebugButton(context, widget.categoryId),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Custom App Bar with Hero Header
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: widget.categoryColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: FadeTransition(
                opacity: _headerAnimation,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.categoryColor,
                        widget.categoryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  widget.categoryIcon,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.categoryName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$completedCount of ${_lessons.length} completed',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.white.withOpacity(0.9),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: LinearProgressIndicator(
                              value: progress / 100,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading State
          if (_loading)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 50,
                      height: 50,
                      child: CircularProgressIndicator(
                        strokeWidth: 5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.categoryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Loading lessons...',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            )
          // Error State
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
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
                      const SizedBox(height: 20),
                      Text(
                        'Failed to load lessons',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Please check your connection and try again',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          // Empty State
          else if (_lessons.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.library_books_outlined,
                          size: 64,
                          color: widget.categoryColor.withOpacity(0.5),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Lessons Available',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Lessons will be added soon!',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onBackground.withOpacity(0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            // Lessons List
            else
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      final lesson = _lessons[index];
                      final lessonId = lesson['id'] as String;
                      final title = _getLocalizedTitle(lesson);
                      final description = _getLocalizedDescription(lesson);
                      final level = lesson['level'] as String?;
                      final wordCount = lesson['wordCount'] as int? ?? 0;
                      final estimatedDuration =
                          lesson['estimatedDuration'] as int? ?? 10;
                      final isCompleted = _completedLessonIds.contains(lessonId);
                      final isUnlocked = _isLessonUnlocked(index);
                      final lessonIcon = _getLessonIcon(index);

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 300 + (index * 50)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 20 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildLessonCard(
                            context,
                            lessonId: lessonId,
                            title: title,
                            description: description,
                            level: level,
                            wordCount: wordCount,
                            duration: estimatedDuration,
                            isCompleted: isCompleted,
                            isUnlocked: isUnlocked,
                            lessonNumber: index + 1,
                            icon: lessonIcon,
                          ),
                        ),
                      );
                    },
                    childCount: _lessons.length,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(
      BuildContext context, {
        required String lessonId,
        required String title,
        required String description,
        required String? level,
        required int wordCount,
        required int duration,
        required bool isCompleted,
        required bool isUnlocked,
        required int lessonNumber,
        required IconData icon,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final levelColor = _getLevelColor(level);
    final levelLabel = _getLevelLabel(level);

    return Opacity(
      opacity: isUnlocked ? 1.0 : 0.6,
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isCompleted
                ? widget.categoryColor.withOpacity(0.5)
                : colorScheme.outline.withOpacity(0.1),
            width: isCompleted ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isCompleted
                  ? widget.categoryColor.withOpacity(0.15)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: isUnlocked
                ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LessonPlayerScreen(
                    lessonId: lessonId,
                    categoryColor: widget.categoryColor,
                    nativeLangCode: widget.nativeLangCode,
                    targetLangCode: widget.targetLangCode,
                  ),
                ),
              ).then((_) => _loadData());
            }
                : null,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  // Lesson Number Badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isUnlocked
                            ? [widget.categoryColor, widget.categoryColor.withOpacity(0.7)]
                            : [Colors.grey, Colors.grey.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: isUnlocked
                          ? [
                        BoxShadow(
                          color: widget.categoryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ]
                          : null,
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isCompleted)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Colors.white,
                            size: 28,
                          )
                        else if (!isUnlocked)
                          const Icon(
                            Icons.lock_rounded,
                            color: Colors.white,
                            size: 24,
                          )
                        else
                          Icon(
                            icon,
                            color: Colors.white,
                            size: 28,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Lesson Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (level != null) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: levelColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  levelLabel,
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: levelColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onBackground.withOpacity(0.6),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 14,
                              color: colorScheme.onBackground.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$duration min',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onBackground.withOpacity(0.5),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.book_outlined,
                              size: 14,
                              color: colorScheme.onBackground.withOpacity(0.5),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$wordCount words',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onBackground.withOpacity(0.5),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isUnlocked
                        ? Icons.arrow_forward_ios_rounded
                        : Icons.lock_outline_rounded,
                    size: 18,
                    color: colorScheme.onBackground.withOpacity(0.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}