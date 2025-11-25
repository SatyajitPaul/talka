// lib/screens/home_screen.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'onboarding_screen.dart';
import 'learning_screen.dart';
import 'dictionary_screen.dart';
import 'profile_screen.dart';

// Models
class Language {
  final String code;
  final String name;
  final String nativeName;
  final String flagEmoji;
  final bool isActive;

  Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flagEmoji,
    required this.isActive,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      code: json['code'] ?? '',
      name: json['name'] ?? json['nativeName'] ?? '',
      nativeName: json['nativeName'] ?? json['name'] ?? '',
      flagEmoji: json['flagEmoji'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }
}

class LanguagePair {
  final String sourceLanguage;
  final String targetLanguage;
  final String displayName;
  final bool isActive;

  LanguagePair({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.displayName,
    required this.isActive,
  });

  factory LanguagePair.fromJson(Map<String, dynamic> json) {
    return LanguagePair(
      sourceLanguage: json['sourceLanguage'] ?? '',
      targetLanguage: json['targetLanguage'] ?? '',
      displayName: json['displayName'] ?? '${json['sourceLanguage']} → ${json['targetLanguage']}',
      isActive: json['isActive'] ?? false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late String _nativeLangCode = 'en';
  late String _targetLangCode = 'es';
  bool _isLoading = true;
  int _currentIndex = 0;
  Map<String, Language> _languages = {};
  Map<String, LanguagePair> _languagePairs = {};

  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fabAnimation = CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    );
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadLanguageData();
    await _loadUserPreferences();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      _fabAnimationController.forward();
    }
  }

  Future<void> _loadLanguageData() async {
    final prefs = await SharedPreferences.getInstance();

    // Load from cache first
    await _loadFromCache(prefs);

    // Update from Firestore
    await _updateFromFirestore(prefs);
  }

  Future<void> _loadFromCache(SharedPreferences prefs) async {
    try {
      final cachedLanguages = prefs.getString('languages_cache');
      final cachedPairs = prefs.getString('language_pairs_cache');

      if (cachedLanguages != null) {
        final decoded = jsonDecode(cachedLanguages) as Map<String, dynamic>;
        final languages = <String, Language>{};
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            languages[key] = Language.fromJson(value);
          }
        });
        _languages = languages;
      }

      if (cachedPairs != null) {
        final decoded = jsonDecode(cachedPairs) as Map<String, dynamic>;
        final pairs = <String, LanguagePair>{};
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            pairs[key] = LanguagePair.fromJson(value);
          }
        });
        _languagePairs = pairs;
      }
    } catch (e) {
      debugPrint('Cache loading error: $e');
    }
  }

  Future<void> _updateFromFirestore(SharedPreferences prefs) async {
    try {
      // Load languages
      final langSnapshot = await FirebaseFirestore.instance
          .collection('languages')
          .where('isActive', isEqualTo: true)
          .get();

      final languages = <String, Language>{};
      for (final doc in langSnapshot.docs) {
        final data = doc.data();
        languages[doc.id] = Language.fromJson(data);
      }
      _languages = languages;
      await prefs.setString('languages_cache', jsonEncode(languages));

      // Load language pairs
      final pairSnapshot = await FirebaseFirestore.instance
          .collection('languagePairs')
          .where('isActive', isEqualTo: true)
          .get();

      final pairs = <String, LanguagePair>{};
      for (final doc in pairSnapshot.docs) {
        final data = doc.data();
        final pair = LanguagePair.fromJson(data);
        // Use source_target as key to identify pairs
        pairs['${pair.sourceLanguage}_${pair.targetLanguage}'] = pair;
      }
      _languagePairs = pairs;
      await prefs.setString('language_pairs_cache', jsonEncode(pairs));
    } catch (e) {
      debugPrint('Firestore loading error: $e');
    }
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    final savedNative = prefs.getString('native_language') ?? 'en';
    final savedTarget = prefs.getString('target_language') ?? 'es';

    // Validate saved languages exist in available options
    String nativeCode = savedNative;
    String targetCode = savedTarget;

    if (!_languages.containsKey(nativeCode)) {
      nativeCode = _languages.containsKey('en') ? 'en' : _languages.keys.firstOrNull ?? 'en';
    }

    // Find appropriate target language based on language pair rules
    targetCode = _findTargetLanguageForNative(nativeCode, savedTarget);

    setState(() {
      _nativeLangCode = nativeCode;
      _targetLangCode = targetCode;
    });
  }

  String _findTargetLanguageForNative(String nativeCode, String preferredTarget) {
    // Check if the preferred target is available for the native language
    final pairKey = '${nativeCode}_${preferredTarget}';
    if (_languagePairs.containsKey(pairKey) &&
        _languagePairs[pairKey]!.isActive) {
      return preferredTarget;
    }

    // Find first available target for the native language
    for (final pair in _languagePairs.values) {
      if (pair.sourceLanguage == nativeCode && pair.isActive) {
        return pair.targetLanguage;
      }
    }

    // Fallback: find any language that's not the native language
    for (final langCode in _languages.keys) {
      if (langCode != nativeCode) {
        return langCode;
      }
    }

    return 'en'; // Final fallback
  }

  Future<void> _saveLanguages(String native, String target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('native_language', native);
    await prefs.setString('target_language', target);

    if (mounted) {
      setState(() {
        _nativeLangCode = native;
        _targetLangCode = target;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('Languages updated successfully!'),
            ],
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sign Out'),
        content: Text('Are you sure you want to sign out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Sign out failed. Please try again.')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      builder: (context) {
        String selectedNative = _nativeLangCode;
        String selectedTarget = _targetLangCode;

        return StatefulBuilder(
          builder: (context, setModalState) {
            // Calculate available targets based on language pairs for the selected native
            final availableTargets = _languagePairs.values
                .where((pair) =>
            pair.sourceLanguage == selectedNative &&
                pair.isActive &&
                pair.targetLanguage != selectedNative) // Extra safety
                .map((pair) => _languages[pair.targetLanguage])
                .where((lang) => lang != null) // Filter out null languages
                .toList();

            // If no valid pairs exist for this native language, fall back to all available languages
            final fallbackTargets = _languages.entries
                .where((entry) => entry.key != selectedNative)
                .toList();

            final useLanguagePairs = availableTargets.isNotEmpty;
            final displayTargets = useLanguagePairs
                ? availableTargets.map((lang) => MapEntry(lang!.code, lang)).toList()
                : fallbackTargets;

            // If current target is not in available targets, select first available
            if (selectedNative != _nativeLangCode) { // Native was changed
              final currentTargetExists = displayTargets.any((entry) => entry.key == selectedTarget);
              if (!currentTargetExists && displayTargets.isNotEmpty) {
                selectedTarget = displayTargets.first.key;
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                32,
                24,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with icon
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.language_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Choose Languages',
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onBackground,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Select the languages you want to use',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Native Language Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.home_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'I speak',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedNative,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.background,
                            prefixIcon: Icon(
                              Icons.flag_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          items: _languages.entries.map((e) {
                            return DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value.name,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() {
                                selectedNative = value;
                                // When native changes, update target based on language pairs
                                final newAvailableTargets = _languagePairs.values
                                    .where((pair) =>
                                pair.sourceLanguage == value &&
                                    pair.isActive &&
                                    pair.targetLanguage != value)
                                    .map((pair) => _languages[pair.targetLanguage])
                                    .where((lang) => lang != null)
                                    .toList();

                                final newFallbackTargets = _languages.entries
                                    .where((entry) => entry.key != value)
                                    .toList();

                                final useNewLanguagePairs = newAvailableTargets.isNotEmpty;
                                final newDisplayTargets = useNewLanguagePairs
                                    ? newAvailableTargets.map((lang) => MapEntry(lang!.code, lang)).toList()
                                    : newFallbackTargets;

                                if (newDisplayTargets.isNotEmpty) {
                                  selectedTarget = newDisplayTargets.first.key;
                                }
                              });
                            }
                          },
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Swap Icon
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: GestureDetector(
                        onTap: () {
                          setModalState(() {
                            // Check if the swap would create valid pairs
                            final newAvailableTargets = _languagePairs.values
                                .where((pair) =>
                            pair.sourceLanguage == selectedTarget &&
                                pair.isActive &&
                                pair.targetLanguage != selectedTarget)
                                .map((pair) => _languages[pair.targetLanguage])
                                .where((lang) => lang != null)
                                .toList();

                            final newFallbackTargets = _languages.entries
                                .where((entry) => entry.key != selectedTarget)
                                .toList();

                            final useNewLanguagePairs = newAvailableTargets.isNotEmpty;
                            final newDisplayTargets = useNewLanguagePairs
                                ? newAvailableTargets.map((lang) => MapEntry(lang!.code, lang)).toList()
                                : newFallbackTargets;

                            final targetExistsInNewList = newDisplayTargets.any((entry) => entry.key == selectedNative);

                            if (targetExistsInNewList) {
                              final temp = selectedNative;
                              selectedNative = selectedTarget;
                              selectedTarget = temp;
                            } else {
                              // If swap would result in invalid target, show error
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('This swap would create an invalid language pair'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }
                          });
                        },
                        child: Icon(
                          Icons.swap_vert_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Target Language Section
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.school_outlined,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'I want to learn',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedTarget,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.background,
                            prefixIcon: Icon(
                              Icons.flag_outlined,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          items: displayTargets.map((e) { // Now uses language pair restrictions
                            return DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value.name,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setModalState(() {
                                selectedTarget = value;
                              });
                            }
                          },
                          dropdownColor: Theme.of(context).colorScheme.surface,
                          icon: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: Navigator.of(context).pop,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () {
                            if (selectedNative == selectedTarget) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('Please select different languages'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                              return;
                            }

                            // Validate that this pair exists in languagePairs
                            final pairKey = '${selectedNative}_${selectedTarget}';
                            if (_languagePairs.containsKey(pairKey) &&
                                _languagePairs[pairKey]!.isActive) {
                              _saveLanguages(selectedNative, selectedTarget);
                              Navigator.of(context).pop();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.white),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text('This language pair is not supported'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.orange.shade600,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: const EdgeInsets.all(16),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text('Save Changes'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withOpacity(0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.waving_hand_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello,',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onBackground.withOpacity(0.6),
                  ),
                ),
                Text(
                  user.displayName?.split(' ')[0] ?? 'Learner',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onBackground,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Language Indicator
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _showLanguageSelector,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.15),
                      colorScheme.primary.withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.translate_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _languages[_targetLangCode]?.name.substring(0, 2).toUpperCase() ?? '??',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down,
                      size: 20,
                      color: colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Logout
          IconButton(
            onPressed: () => _logout(context),
            icon: Icon(Icons.logout_outlined),
            color: colorScheme.primary,
            tooltip: 'Sign out',
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Loading your learning journey...',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onBackground.withOpacity(0.6),
              ),
            ),
          ],
        ),
      )
          : IndexedStack(
        index: _currentIndex,
        children: [
          LearningScreen(
            nativeLangCode: _nativeLangCode,
            targetLangCode: _targetLangCode,
          ),
          DictionaryScreen(
            user: user,
            nativeLangCode: _nativeLangCode,
            targetLangCode: _targetLangCode,
          ),
          ProfileScreen(user: user),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) {
            if (!mounted) return;
            setState(() {
              _currentIndex = idx;
            });
          },
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onBackground.withOpacity(0.5),
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          backgroundColor: colorScheme.surface,
          selectedLabelStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.school_outlined),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school_rounded),
              ),
              label: 'Learning',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.menu_book_outlined),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.menu_book_rounded),
              ),
              label: 'Dictionary',
            ),
            BottomNavigationBarItem(
              icon: Container(
                padding: const EdgeInsets.all(8),
                child: Icon(Icons.person_outline),
              ),
              activeIcon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.person_rounded),
              ),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}