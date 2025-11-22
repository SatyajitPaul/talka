// lib/screens/home_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_screen.dart';
import 'learning_screen.dart';
import 'dictionary_screen.dart';
import 'profile_screen.dart';

// Language options are loaded from Firestore and cached locally.

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String nativeLangCode = 'en';
  late String targetLangCode = 'ta';
  bool _isLoading = true;
  int _currentIndex = 0;
  // languageOptions will be populated from Firestore (code -> display name)
  Map<String, String> languageOptions = {'en': 'English', 'ta': 'Tamil'};

  // full metadata cache (code -> map)
  Map<String, Map<String, dynamic>> languageMeta = {};

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    await _loadLanguageOptions();
    await _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNative = prefs.getString('native_language') ?? 'en';
    final savedTarget = prefs.getString('target_language') ?? 'ta';

    // Validate against known languages (if not known yet, accept saved value; we'll revalidate after languages load)
    nativeLangCode = savedNative;
    targetLangCode = savedTarget;

    // try to revalidate against loaded options
    if (!languageOptions.containsKey(nativeLangCode))
      nativeLangCode = languageOptions.containsKey('en')
          ? 'en'
          : languageOptions.keys.first;
    if (!languageOptions.containsKey(targetLangCode))
      targetLangCode = languageOptions.containsKey('ta')
          ? 'ta'
          : languageOptions.keys.where((k) => k != nativeLangCode).isNotEmpty
          ? languageOptions.keys.firstWhere((k) => k != nativeLangCode)
          : languageOptions.keys.first;

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLanguageOptions() async {
    final prefs = await SharedPreferences.getInstance();
    // load cached options first
    final cached = prefs.getString('language_options_cache');
    if (cached != null) {
      try {
        final Map<String, dynamic> parsed = Map<String, dynamic>.from(
          jsonDecode(cached),
        );
        final Map<String, String> opts = {};
        final Map<String, Map<String, dynamic>> meta = {};
        parsed.forEach((key, value) {
          final m = Map<String, dynamic>.from(value as Map);
          final display = (m['name'] ?? m['nativeName'] ?? key).toString();
          opts[key] = display;
          meta[key] = m;
        });
        if (mounted)
          setState(() {
            languageOptions = opts;
            languageMeta = meta;
          });
      } catch (_) {}
    }

    // fetch latest from Firestore
    try {
      final snap = await FirebaseFirestore.instance
          .collection('languages')
          .where('isActive', isEqualTo: true)
          .get();
      final Map<String, Map<String, dynamic>> meta = {};
      final Map<String, String> opts = {};
      for (final d in snap.docs) {
        final m = Map<String, dynamic>.from(d.data());
        final display = (m['name'] ?? m['nativeName'] ?? d.id).toString();
        meta[d.id] = m;
        opts[d.id] = display;
      }
      // persist cache
      await prefs.setString('language_options_cache', jsonEncode(meta));
      if (mounted) {
        setState(() {
          languageOptions = opts;
          languageMeta = meta;
        });
      }

      // Re-validate selected languages if necessary
      final savedNative = prefs.getString('native_language') ?? nativeLangCode;
      final savedTarget = prefs.getString('target_language') ?? targetLangCode;
      if (mounted) {
        setState(() {
          nativeLangCode = opts.containsKey(savedNative)
              ? savedNative
              : (opts.containsKey('en') ? 'en' : opts.keys.first);
          targetLangCode = opts.containsKey(savedTarget)
              ? savedTarget
              : (opts.keys.firstWhere(
                  (k) => k != nativeLangCode,
                  orElse: () => opts.keys.first,
                ));
        });
      }
    } catch (e) {
      // ignore fetch errors; keep cached or defaults
    }
  }

  Future<void> _saveLanguages(String native, String target) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('native_language', native);
    await prefs.setString('target_language', target);
    if (mounted) {
      setState(() {
        nativeLangCode = native;
        targetLangCode = target;
      });
    }
  }

  void _logout(BuildContext context) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sign out failed: $e')));
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).colorScheme.background,
      builder: (context) {
        String selectedNative = nativeLangCode;
        String selectedTarget = targetLangCode;

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
              Text(
                'Choose Languages',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your native language and the language you want to learn.',
                style: TextStyle(color: const Color(0xFF6c757d), fontSize: 14),
              ),
              const SizedBox(height: 24),

              // Native Language Dropdown
              Text(
                'I speak:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedNative,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: languageOptions.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedNative = value;
                  }
                },
                dropdownColor: Colors.white,
              ),
              const SizedBox(height: 20),

              // Target Language Dropdown
              Text(
                'I want to learn:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedTarget,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                items: languageOptions.entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value));
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    selectedTarget = value;
                  }
                },
                dropdownColor: Colors.white,
              ),
              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (selectedNative == selectedTarget) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Languages must be different!'),
                        ),
                      );
                      return;
                    }
                    _saveLanguages(selectedNative, selectedTarget);
                    Navigator.of(context).pop(); // Close bottom sheet
                  },
                  child: const Text('Save & Continue'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    // display abbreviations in the appbar; values come from `languageOptions`

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Hi, ${user.displayName?.split(' ')[0] ?? 'Learner'}!',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF3f37c9),
          ),
        ),
        actions: [
          // Language Indicator + Picker
          GestureDetector(
            onTap: _showLanguageSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF4361ee).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${languageOptions[targetLangCode]?.substring(0, 2).toUpperCase() ?? '??'}',
                    style: TextStyle(
                      color: const Color(0xFF4361ee),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: Color(0xFF4361ee),
                  ),
                ],
              ),
            ),
          ),
          // Logout
          IconButton(
            onPressed: () => _logout(context),
            icon: const Icon(Icons.logout_outlined),
            color: const Color(0xFF4361ee),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _currentIndex,
              children: [
                LearningScreen(
                  nativeLangCode: nativeLangCode,
                  targetLangCode: targetLangCode,
                ),
                DictionaryScreen(
                  user: user,
                  nativeLangCode: nativeLangCode,
                  targetLangCode: targetLangCode,
                ),
                ProfileScreen(user: user),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) {
          if (!mounted) return;
          setState(() {
            _currentIndex = idx;
          });
        },
        selectedItemColor: const Color(0xFF4361ee),
        unselectedItemColor: const Color(0xFF6c757d),
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.school_outlined),
            label: 'Learning',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            label: 'Dictionary',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
