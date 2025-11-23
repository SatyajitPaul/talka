// lib/screens/profile_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

// --- Color Constants ---
const Color kBeginnerColor = Color(0xFF4361ee);
const Color kIntermediateColor = Color(0xFF7209b7);
const Color kAdvancedColor = Color(0xFFf72585);
const Color kExpertColor = Color(0xFF06ffa5);

// --- Level Logic ---
enum UserLevel {
  beginner(0, 50, 'Beginner', kBeginnerColor),
  intermediate(50, 200, 'Intermediate', kIntermediateColor),
  advanced(200, 500, 'Advanced', kAdvancedColor),
  expert(500, 999999, 'Expert', kExpertColor);

  const UserLevel(this.minWords, this.maxWords, this.title, this.color);

  final int minWords, maxWords;
  final String title;
  final Color color;

  static UserLevel fromWords(int words) {
    for (var level in UserLevel.values.reversed) {
      if (words >= level.minWords) return level;
    }
    return beginner;
  }

  double progressFor(int words) {
    if (this == expert) return 1.0;
    final actual = words.clamp(minWords, maxWords - 1);
    return (actual - minWords) / (maxWords - minWords);
  }

  String nextLevelMessage(int words) {
    if (this == expert) return 'Max level reached!';
    return '${maxWords - words} words to ${UserLevel.values[index + 1].title}';
  }
}

class ProfileScreen extends StatefulWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  int _totalWords = 0;
  int _completedTopics = 0;
  int _streakDays = 0;
  bool _loading = true;
  UserLevel _level = UserLevel.beginner;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(widget.user.uid)
          .get(const GetOptions(source: Source.serverAndCache))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (doc.exists) {
        final data = doc.data();
        final words = (data?['completedWords'] as List<dynamic>?)?.length ?? 0;
        final topics = (data?['completedSubcategories'] as List<dynamic>?)?.length ?? 0;
        final streak = (data?['streakDays'] as int?) ?? 0;

        final level = UserLevel.fromWords(words);

        setState(() {
          _totalWords = words;
          _completedTopics = topics;
          _streakDays = streak;
          _level = level;
        });
      }
    } catch (e, stack) {
      if (!mounted) return;
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'ProfileScreen',
        context: ErrorDescription('Failed to load user stats'),
      ));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to load profile. Pull to retry.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
      _animationController.reset();
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _loadUserStats,
      color: colorScheme.primary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 16),

                // Profile Picture with Level Ring
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: TweenAnimationBuilder<double>(
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        tween: Tween(begin: 0.0, end: _level.progressFor(_totalWords)),
                        builder: (context, value, child) {
                          return CircularProgressIndicator(
                            value: value,
                            strokeWidth: 6,
                            backgroundColor: colorScheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation<Color>(_level.color),
                          );
                        },
                      ),
                    ),
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            colorScheme.primary.withOpacity(0.3),
                            colorScheme.primary.withOpacity(0.1),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _level.color.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: widget.user.photoURL != null
                          ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: widget.user.photoURL!,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: colorScheme.surfaceVariant,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Icon(
                            Icons.person_rounded,
                            size: 60,
                            color: colorScheme.primary,
                          ),
                        ),
                      )
                          : Icon(
                        Icons.person_rounded,
                        size: 60,
                        color: colorScheme.primary,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _level.color,
                              _level.color.withOpacity(0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: _level.color.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.stars_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _level.title,
                              style: textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Name and Email
                Text(
                  widget.user.displayName ?? 'Language Learner',
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (widget.user.email != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: colorScheme.onBackground.withOpacity(0.6),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.user.email!,
                          style: textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onBackground.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 32),

                // Stats Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.library_books_rounded,
                        value: _totalWords.toString(),
                        label: 'Words Learned',
                        color: kBeginnerColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.check_circle_rounded,
                        value: _completedTopics.toString(),
                        label: 'Topics Done',
                        color: kExpertColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.local_fire_department_rounded,
                        value: _streakDays.toString(),
                        label: 'Day Streak',
                        color: kAdvancedColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.calendar_today_rounded,
                        value: _formatMemberSince(),
                        label: 'Member Since',
                        color: kIntermediateColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Level Progress Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _level.color.withOpacity(0.15),
                        _level.color.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _level.color.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _level.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.trending_up_rounded,
                              color: _level.color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Level Progress',
                                  style: textTheme.labelLarge?.copyWith(
                                    color: colorScheme.onBackground.withOpacity(0.6),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _level.nextLevelMessage(_totalWords),
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: _level.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: TweenAnimationBuilder<double>(
                          duration: const Duration(milliseconds: 1500),
                          curve: Curves.easeOutCubic,
                          tween: Tween(begin: 0.0, end: _level.progressFor(_totalWords)),
                          builder: (context, value, child) {
                            return LinearProgressIndicator(
                              value: value,
                              backgroundColor: colorScheme.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation<Color>(_level.color),
                              minHeight: 12,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Account Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.outline.withOpacity(0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Details',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildDetailRow(
                        context,
                        icon: Icons.verified_user_rounded,
                        label: 'Account Status',
                        value: widget.user.emailVerified
                            ? 'Verified'
                            : 'Not Verified',
                        valueColor: widget.user.emailVerified
                            ? kExpertColor
                            : Colors.orange,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        context,
                        icon: Icons.login_rounded,
                        label: 'Sign-in Method',
                        value: _getSignInMethod(),
                        valueColor: colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      _buildDetailRow(
                        context,
                        icon: Icons.security_rounded,
                        label: 'User ID',
                        value: '${widget.user.uid.substring(0, 8)}...',
                        valueColor: colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Achievements Section
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.secondary.withOpacity(0.1),
                        colorScheme.primary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colorScheme.primary.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 48,
                        color: colorScheme.primary.withOpacity(0.6),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Achievements',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Earn badges by completing challenges',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onBackground.withOpacity(0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Coming Soon',
                          style: textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context, {
        required IconData icon,
        required String value,
        required String label,
        required Color color,
      }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onBackground.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
        required Color valueColor,
      }) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: valueColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: valueColor, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                ),
              ),
              Text(
                value,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatMemberSince() {
    final creationTime = widget.user.metadata.creationTime;
    if (creationTime == null) return 'Unknown';
    return DateFormat('MMM yyyy').format(creationTime);
  }

  String _getSignInMethod() {
    final providers = widget.user.providerData;
    if (providers.isEmpty) return 'Email';

    final provider = providers.first.providerId;
    if (provider.contains('google')) return 'Google';
    if (provider.contains('password')) return 'Email';
    return 'Other';
  }
}