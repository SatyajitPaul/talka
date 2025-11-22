// lib/screens/home_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

// Language options (you can expand this list)
const Map<String, String> languageOptions = {
  'en': 'English',
  'ta': 'Tamil',
  'hi': 'Hindi',
  'bn': 'Bengali',
  'te': 'Telugu',
  'mr': 'Marathi',
};

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late String nativeLangCode = 'en';
  late String targetLangCode = 'ta';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final prefs = await SharedPreferences.getInstance();
    final savedNative = prefs.getString('native_language') ?? 'en';
    final savedTarget = prefs.getString('target_language') ?? 'ta';

    // Validate against known languages
    nativeLangCode = languageOptions.containsKey(savedNative) ? savedNative : 'en';
    targetLangCode = languageOptions.containsKey(savedTarget) ? savedTarget : 'ta';

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
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
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/splash', (route) => false);
  }

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
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
                style: TextStyle(
                  color: const Color(0xFF6c757d),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Native Language Dropdown
              Text(
                'I speak:',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  );
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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
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
                  return DropdownMenuItem(
                    value: e.key,
                    child: Text(e.value),
                  );
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
                        const SnackBar(content: Text('Languages must be different!')),
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
    final nativeLang = languageOptions[nativeLangCode] ?? 'English';
    final targetLang = languageOptions[targetLangCode] ?? 'Tamil';
    final appBarTitle = 'Learning $targetLang with $nativeLang';

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
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Profile Image with glow
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: const Color(0xFF4361ee).withOpacity(0.15),
                        child: CircleAvatar(
                          radius: 64,
                          backgroundImage: user.photoURL != null
                              ? CachedNetworkImageProvider(user.photoURL!)
                              : null,
                          child: user.photoURL == null
                              ? Icon(
                                  Icons.person,
                                  size: 60,
                                  color: const Color(0xFF4361ee),
                                )
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    user.displayName ?? 'Language Learner',
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF212529),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? '',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFF6c757d),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Language Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Current Learning Path',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF3f37c9),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: nativeLang,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const TextSpan(text: ' → '),
                              TextSpan(
                                text: targetLang,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4361ee),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: const Color(0xFF212529),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap the language tag in the top-right to change your learning path.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFF6c757d),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}