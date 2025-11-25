// lib/screens/learning_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'category_lessons_screen.dart';

class LearningScreen extends StatefulWidget {
  final String nativeLangCode;
  final String targetLangCode;

  const LearningScreen({
    super.key,
    required this.nativeLangCode,
    required this.targetLangCode,
  });

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen>
    with TickerProviderStateMixin {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  Map<String, int> _categoryLessonCounts = {};
  Map<String, int> _categoryCompletedCounts = {};
  Set<String> _completedLessonIds = {};
  int _totalWordsLearned = 0;
  int _currentStreak = 0;

  late AnimationController _headerAnimationController;
  late Animation<double> _headerFadeAnimation;
  late AnimationController _floatingController;

  @override
  void initState() {
    super.initState();
    _headerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeOut,
    );
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Load categories first
      await _loadCategories();

      // Then load user progress
      await _loadUserProgress();

      // Finally load lesson counts (needs categories to be loaded first)
      await _loadLessonCounts();

      _headerAnimationController.forward();
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

  Future<void> _loadCategories() async {
    final catSnap = await FirebaseFirestore.instance
        .collection('categories')
        .where('isActive', isEqualTo: true)
        .orderBy('order')
        .get();

    final categories = catSnap.docs
        .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
        .toList();

    debugPrint('📂 Loaded ${categories.length} categories:');
    for (var cat in categories) {
      debugPrint('   - ${cat['id']}: ${cat['name']} / ${cat['translations']}');
    }

    setState(() {
      _categories = categories;
    });
  }

  Future<void> _loadUserProgress() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(userId)
          .get();

      if (doc.exists) {
        final data = doc.data();
        final completedLessons = List<String>.from(data?['completedLessons'] ?? []);
        final completedWords = List<String>.from(data?['completedWords'] ?? []);

        setState(() {
          _completedLessonIds = Set<String>.from(completedLessons);
          _totalWordsLearned = completedWords.length;
          _currentStreak = data?['currentStreak'] ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading progress: $e');
    }
  }

  Future<void> _loadLessonCounts() async {
    final counts = <String, int>{};
    final completedCounts = <String, int>{};

    debugPrint('🔍 Starting to load lesson counts for ${_categories.length} categories');

    for (final cat in _categories) {
      final categoryId = cat['id'] as String;
      final categoryName = _getLocalizedName(cat['translations'] as Map<String, dynamic>?);

      debugPrint('📚 Loading lessons for category: $categoryName (ID: $categoryId)');

      try {
        // Try WITHOUT isActive filter first to see if lessons exist at all
        final allLessonsSnap = await FirebaseFirestore.instance
            .collection('lessons')
            .where('categoryId', isEqualTo: categoryId)
            .get();

        debugPrint('   Found ${allLessonsSnap.docs.length} total lessons (without isActive filter)');

        // Log details of each lesson
        for (var doc in allLessonsSnap.docs) {
          final lessonData = doc.data();
          debugPrint('   - Lesson: ${doc.id}');
          debugPrint('     title: ${lessonData['title']}');
          debugPrint('     isActive: ${lessonData['isActive']}');
          debugPrint('     categoryId: ${lessonData['categoryId']}');
        }

        // Now filter for active lessons
        final activeLessons = allLessonsSnap.docs.where((doc) {
          final data = doc.data();
          final isActive = data['isActive'];
          // Handle both boolean and null (treat null as true for backward compatibility)
          return isActive == true || isActive == null;
        }).toList();

        final totalLessons = activeLessons.length;
        final completedInCategory = activeLessons
            .where((doc) => _completedLessonIds.contains(doc.id))
            .length;

        counts[categoryId] = totalLessons;
        completedCounts[categoryId] = completedInCategory;

        debugPrint('   ✅ Active lessons: $totalLessons, Completed: $completedInCategory');
      } catch (e, stackTrace) {
        debugPrint('   ❌ Error loading lesson count for category $categoryId: $e');
        debugPrint('   Stack trace: $stackTrace');
        counts[categoryId] = 0;
        completedCounts[categoryId] = 0;
      }
    }

    debugPrint('🎯 Final lesson counts: $counts');
    debugPrint('🎯 Final completed counts: $completedCounts');

    setState(() {
      _categoryLessonCounts = counts;
      _categoryCompletedCounts = completedCounts;
    });
  }

  String _getLocalizedName(Map<String, dynamic>? translations) {
    if (translations == null) return '';
    try {
      final trans = Map<String, dynamic>.from(translations);
      return (trans[widget.nativeLangCode] ?? trans.values.first ?? '')
          .toString();
    } catch (_) {
      return '';
    }
  }

  int _getCategoryProgress(String categoryId) {
    final total = _categoryLessonCounts[categoryId] ?? 0;
    if (total == 0) return 0;
    final completed = _categoryCompletedCounts[categoryId] ?? 0;
    return ((completed / total) * 100).round();
  }

  Color _getCategoryColor(int index) {
    final colors = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFFEC4899), // Pink
      const Color(0xFF10B981), // Emerald
      const Color(0xFFF59E0B), // Amber
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFEF4444), // Red
      const Color(0xFF3B82F6), // Blue
    ];
    return colors[index % colors.length];
  }

  IconData _getCategoryIcon(String? iconName) {
    final iconMap = {
      'abc': Icons.abc_rounded,
      'chat': Icons.chat_bubble_rounded,
      'food': Icons.restaurant_rounded,
      'travel': Icons.flight_rounded,
      'work': Icons.work_rounded,
      'home': Icons.home_rounded,
      'school': Icons.school_rounded,
      'health': Icons.favorite_rounded,
      'sports': Icons.sports_soccer_rounded,
      'shopping': Icons.shopping_bag_rounded,
      'music': Icons.music_note_rounded,
      'nature': Icons.park_rounded,
    };
    return iconMap[iconName?.toLowerCase()] ?? Icons.category_rounded;
  }

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _floatingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final size = MediaQuery.of(context).size;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: colorScheme.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero Header
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _headerFadeAnimation,
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withOpacity(0.7),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Learning Path',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.white.withOpacity(0.9),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.nativeLangCode.toUpperCase()} → ${widget.targetLangCode.toUpperCase()}',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _floatingController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(
                                0,
                                math.sin(_floatingController.value * 2 * math.pi) * 8,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(
                                  Icons.rocket_launch_rounded,
                                  color: Colors.white,
                                  size: 36,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.book_rounded,
                            label: 'Words',
                            value: _totalWordsLearned.toString(),
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Streak',
                            value: '$_currentStreak days',
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildStatCard(
                            icon: Icons.emoji_events_rounded,
                            label: 'Lessons',
                            value: _completedLessonIds.length.toString(),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Section Title
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Explore Categories',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_categories.length} topics to master',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ],
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
                      width: 60,
                      height: 60,
                      child: CircularProgressIndicator(
                        strokeWidth: 6,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading your journey...',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.7),
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
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.cloud_off_rounded,
                          size: 64,
                          color: Colors.red.shade400,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Connection Lost',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to load categories. Please check your connection.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _loadData,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          // Empty State
          else if (_categories.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.explore_off_rounded,
                            size: 64,
                            color: colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No Categories Yet',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'New learning adventures are coming soon!',
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
            // Categories Grid
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, idx) {
                      final cat = _categories[idx];
                      final catId = cat['id'] as String;
                      final catName = _getLocalizedName(
                        cat['translations'] as Map<String, dynamic>?,
                      );
                      final description = cat['description'] as String? ?? '';
                      final lessonCount = _categoryLessonCounts[catId] ?? 0;
                      final progress = _getCategoryProgress(catId);
                      final color = _getCategoryColor(idx);
                      final icon = _getCategoryIcon(cat['icon'] as String?);

                      return TweenAnimationBuilder<double>(
                        duration: Duration(milliseconds: 400 + (idx * 80)),
                        tween: Tween(begin: 0.0, end: 1.0),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 30 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildCategoryCard(
                            context,
                            categoryId: catId,
                            name: catName,
                            description: description,
                            lessonCount: lessonCount,
                            progress: progress,
                            color: color,
                            icon: icon,
                          ),
                        ),
                      );
                    },
                    childCount: _categories.length,
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
      BuildContext context, {
        required String categoryId,
        required String name,
        required String description,
        required int lessonCount,
        required int progress,
        required Color color,
        required IconData icon,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isCompleted = progress == 100;

    // Debug print when building card
    debugPrint('🎴 Building card for: $name (ID: $categoryId) - Lessons: $lessonCount');

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCompleted
              ? color.withOpacity(0.5)
              : colorScheme.outline.withOpacity(0.1),
          width: isCompleted ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: lessonCount > 0
              ? () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryLessonsScreen(
                  categoryId: categoryId,
                  categoryName: name,
                  categoryColor: color,
                  categoryIcon: icon,
                  nativeLangCode: widget.nativeLangCode,
                  targetLangCode: widget.targetLangCode,
                ),
              ),
            ).then((_) => _loadData());
          }
              : () {
            // Show debug info when tapped with 0 lessons
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Debug Info'),
                content: Text(
                  'Category ID: $categoryId\n'
                      'Name: $name\n'
                      'Lesson Count: $lessonCount\n\n'
                      'Check console for detailed logs.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon Container
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    // Title and Lesson Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.isNotEmpty ? name : 'Untitled',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 16,
                                color: colorScheme.onBackground.withOpacity(0.5),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$lessonCount ${lessonCount == 1 ? 'lesson' : 'lessons'}',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onBackground.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Completion Badge
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_rounded,
                          color: color,
                          size: 24,
                        ),
                      )
                    else
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 18,
                        color: colorScheme.onBackground.withOpacity(0.3),
                      ),
                  ],
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onBackground.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (progress > 0) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: progress / 100,
                            backgroundColor: colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$progress%',
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}