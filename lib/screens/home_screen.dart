// lib/screens/home_screen.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import your other screens
import 'onboarding_screen.dart';
import 'learning_screen.dart';
import 'dictionary_screen.dart';
import 'profile_screen.dart';

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------

class Language {
  final String code;
  final String name;
  final String nativeName;
  final String flagEmoji;
  final bool isActive;

  const Language({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flagEmoji,
    required this.isActive,
  });

  factory Language.fromJson(Map<String, dynamic> json) {
    return Language(
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      nativeName: json['nativeName'] ?? '',
      flagEmoji: json['flagEmoji'] ?? '🏳️',
      isActive: json['isActive'] ?? false,
    );
  }
}

class LanguagePair {
  final String sourceLanguage;
  final String targetLanguage;
  final String displayName;
  final bool isActive;

  const LanguagePair({
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.displayName,
    required this.isActive,
  });

  factory LanguagePair.fromJson(Map<String, dynamic> json) {
    return LanguagePair(
      sourceLanguage: json['sourceLanguage'] ?? '',
      targetLanguage: json['targetLanguage'] ?? '',
      displayName: json['displayName'] ?? '',
      isActive: json['isActive'] ?? false,
    );
  }
}

// -----------------------------------------------------------------------------
// HOME SCREEN
// -----------------------------------------------------------------------------

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String _nativeLangCode = 'en';
  late String _targetLangCode = 'es';
  bool _isLoading = true;
  int _currentIndex = 0;

  Map<String, Language> _languages = {};
  Map<String, LanguagePair> _languagePairs = {};

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _loadLanguageData();
    await _loadUserPreferences();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLanguageData() async {
    final prefs = await SharedPreferences.getInstance();
    await _loadFromCache(prefs);
    _updateFromFirestore(prefs);
  }

  Future<void> _loadFromCache(SharedPreferences prefs) async {
    try {
      final cachedLanguages = prefs.getString('languages_cache');
      final cachedPairs = prefs.getString('language_pairs_cache');

      if (cachedLanguages != null) {
        final decoded = jsonDecode(cachedLanguages) as Map<String, dynamic>;
        _languages = decoded.map((k, v) => MapEntry(k, Language.fromJson(v)));
      }

      if (cachedPairs != null) {
        final decoded = jsonDecode(cachedPairs) as Map<String, dynamic>;
        _languagePairs = decoded.map((k, v) => MapEntry(k, LanguagePair.fromJson(v)));
      }
    } catch (e) {
      debugPrint('Cache load error: $e');
    }
  }

  Future<void> _updateFromFirestore(SharedPreferences prefs) async {
    try {
      final langSnapshot = await FirebaseFirestore.instance
          .collection('languages')
          .where('isActive', isEqualTo: true)
          .get();

      final languages = <String, Language>{};
      for (final doc in langSnapshot.docs) {
        languages[doc.id] = Language.fromJson(doc.data());
      }

      final pairSnapshot = await FirebaseFirestore.instance
          .collection('languagePairs')
          .where('isActive', isEqualTo: true)
          .get();

      final pairs = <String, LanguagePair>{};
      for (final doc in pairSnapshot.docs) {
        final data = doc.data();
        final pair = LanguagePair.fromJson(data);
        pairs['${pair.sourceLanguage}_${pair.targetLanguage}'] = pair;
      }

      if (mounted) {
        setState(() {
          _languages = languages;
          _languagePairs = pairs;
        });
      }

      await prefs.setString('languages_cache', jsonEncode(languages));
      await prefs.setString('language_pairs_cache', jsonEncode(pairs));
    } catch (e) {
      debugPrint('Firestore update error: $e');
    }
  }

  Future<void> _loadUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    String native = prefs.getString('native_language') ?? 'en';
    String target = prefs.getString('target_language') ?? 'es';

    if (!_languages.containsKey(native)) {
      native = _languages.keys.firstOrNull ?? 'en';
    }

    // Ensure pair validity
    final pairKey = '${native}_${target}';
    if (!_languagePairs.containsKey(pairKey)) {
      final validPair = _languagePairs.values.firstWhere(
              (p) => p.sourceLanguage == native,
          orElse: () => LanguagePair(sourceLanguage: native, targetLanguage: 'en', displayName: '', isActive: true)
      );
      target = validPair.targetLanguage;
    }

    if (mounted) {
      setState(() {
        _nativeLangCode = native;
        _targetLangCode = target;
      });
    }
  }

  Future<void> _saveLanguagePreferences(String native, String target) async {
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
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('Learning path updated!'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _LanguageSelectorSheet(
        initialNativeCode: _nativeLangCode,
        initialTargetCode: _targetLangCode,
        languages: _languages,
        languagePairs: _languagePairs,
        onSave: _saveLanguagePreferences,
      ),
    );
  }

  void _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = FirebaseAuth.instance.currentUser;
    final currentLang = _languages[_targetLangCode];

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Text((user?.displayName ?? 'U')[0].toUpperCase())
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hello,', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                  Text(
                    user?.displayName?.split(' ').first ?? 'Learner',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          InkWell(
            onTap: _showLanguageSelector,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              decoration: BoxDecoration(
                color: colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colorScheme.outline.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Text(currentLang?.flagEmoji ?? '🏳️'),
                  const SizedBox(width: 6),
                  Text(
                    currentLang?.code.toUpperCase() ?? 'EN',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                  const Icon(Icons.keyboard_arrow_down, size: 16),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            color: colorScheme.error,
            tooltip: "Log out",
            onPressed: _logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : IndexedStack(
        index: _currentIndex,
        children: [
          LearningScreen(nativeLangCode: _nativeLangCode, targetLangCode: _targetLangCode),
          DictionaryScreen(user: user!, nativeLangCode: _nativeLangCode, targetLangCode: _targetLangCode),
          ProfileScreen(user: user),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 2,
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
          backgroundColor: colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          height: 70,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school_rounded),
              label: 'Learn',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book_rounded),
              label: 'Dictionary',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// IMPROVED PAGINATED SELECTOR SHEET
// -----------------------------------------------------------------------------

// -----------------------------------------------------------------------------
// IMPROVED PAGINATED SELECTOR SHEET
// -----------------------------------------------------------------------------

class _LanguageSelectorSheet extends StatefulWidget {
  final String initialNativeCode;
  final String initialTargetCode;
  final Map<String, Language> languages;
  final Map<String, LanguagePair> languagePairs;
  final Function(String, String) onSave;

  const _LanguageSelectorSheet({
    required this.initialNativeCode,
    required this.initialTargetCode,
    required this.languages,
    required this.languagePairs,
    required this.onSave,
  });

  @override
  State<_LanguageSelectorSheet> createState() => _LanguageSelectorSheetState();
}

class _LanguageSelectorSheetState extends State<_LanguageSelectorSheet> {
  late PageController _pageController;
  int _currentPage = 0;

  String? _selectedNative;
  String? _selectedTarget;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _selectedNative = widget.initialNativeCode;
    _selectedTarget = widget.initialTargetCode;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // --- Logic Helpers ---

  List<Language> _getValidSourceLanguages() {
    final validSourceCodes = widget.languagePairs.values
        .where((p) => p.isActive)
        .map((p) => p.sourceLanguage)
        .toSet();

    return widget.languages.values
        .where((l) => validSourceCodes.contains(l.code))
        .toList();
  }

  List<Language> _getValidTargetLanguages() {
    if (_selectedNative == null) return [];

    return widget.languagePairs.values
        .where((pair) =>
    pair.sourceLanguage == _selectedNative &&
        pair.isActive &&
        pair.targetLanguage != _selectedNative)
        .map((pair) => widget.languages[pair.targetLanguage])
        .whereType<Language>()
        .toList();
  }

  void _handleNativeSelect(String code) {
    setState(() {
      _selectedNative = code;
      // Reset target if it's not valid for the new native
      final validTargets = _getValidTargetLanguages();
      if (!validTargets.any((l) => l.code == _selectedTarget)) {
        _selectedTarget = null;
      }
    });

    // Auto-advance to next page
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _handleBack() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _isSelectionValid() {
    if (_selectedNative == null || _selectedTarget == null) return false;
    final pairKey = '${_selectedNative}_${_selectedTarget}';
    return widget.languagePairs.containsKey(pairKey) &&
        widget.languagePairs[pairKey]!.isActive;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final validSources = _getValidSourceLanguages();
    final validTargets = _getValidTargetLanguages();

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Navigation Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    // Back Button (Hidden on first page)
                    SizedBox(
                      width: 48,
                      child: _currentPage > 0
                          ? IconButton(
                        onPressed: _handleBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                      )
                          : null,
                    ),

                    // Dynamic Title
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Text(
                          _currentPage == 0 ? 'I speak' : 'I want to learn',
                          key: ValueKey<int>(_currentPage),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),

                    // Close Button
                    SizedBox(
                      width: 48,
                      child: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        style: IconButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Prevent manual swiping without selection
                  onPageChanged: (idx) {
                    setState(() => _currentPage = idx);
                  },
                  children: [
                    // STEP 1: I Speak
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                      children: [
                        _buildLanguageGrid(
                          context,
                          validSources,
                          _selectedNative,
                          _handleNativeSelect,
                        ),
                      ],
                    ),

                    // STEP 2: I Want to Learn
                    ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 100),
                      children: [
                        if (validTargets.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 40),
                            child: Column(
                              children: [
                                Icon(Icons.school_outlined, size: 48, color: theme.colorScheme.outline),
                                const SizedBox(height: 16),
                                // FIXED LINE BELOW
                                Text(
                                  "No courses available from ${widget.languages[_selectedNative]?.name ?? 'this language'} yet.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          )
                        else
                          _buildLanguageGrid(
                            context,
                            validTargets,
                            _selectedTarget,
                                (code) => setState(() => _selectedTarget = code),
                            isTarget: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Bottom Action Bar (Context Aware)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -4),
                      blurRadius: 16,
                    )
                  ],
                ),
                child: SafeArea(
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _currentPage == 1 && _isSelectionValid()
                          ? () {
                        widget.onSave(_selectedNative!, _selectedTarget!);
                        Navigator.pop(context);
                      }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        disabledBackgroundColor: theme.colorScheme.onSurface.withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == 0 ? 'Select a language' : 'Start Learning',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLanguageGrid(
      BuildContext context,
      List<Language> languages,
      String? selectedCode,
      Function(String) onSelect,
      {bool isTarget = false}
      ) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: languages.map((lang) {
            final isSelected = lang.code == selectedCode;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(lang.code);
                },
                borderRadius: BorderRadius.circular(16),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: itemWidth,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? theme.colorScheme.primary.withOpacity(0.1)
                        : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(lang.flagEmoji, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.name,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              lang.nativeName,
                              style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, size: 16, color: theme.colorScheme.primary),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}