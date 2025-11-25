// lib/screens/lessons/introduction_exercise_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_langdetect/flutter_langdetect.dart' as langdetect;

class IntroductionExerciseScreen extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final Color categoryColor;
  final VoidCallback onComplete;

  const IntroductionExerciseScreen({
    super.key,
    required this.exercise,
    required this.categoryColor,
    required this.onComplete,
  });

  @override
  State<IntroductionExerciseScreen> createState() => _IntroductionExerciseScreenState();
}

class _IntroductionExerciseScreenState extends State<IntroductionExerciseScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isComplete = false;
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
    _initTts();
  }

  void _initTts() async {
    await _flutterTts.setSpeechRate(0.4);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
  }

  void _onPageChanged() {
    setState(() {
      _currentPage = _pageController.page?.round() ?? 0;
    });
  }

  Future<void> _speak(String text) async {
    if (_isSpeaking) {
      await _flutterTts.stop();
      setState(() {
        _isSpeaking = false;
      });
      return;
    }

    setState(() {
      _isSpeaking = true;
    });

    // Detect language and set appropriate TTS language
    String detectedLang = await _detectLanguage(text);
    await _flutterTts.setLanguage(detectedLang);

    await _flutterTts.speak(text);

    _flutterTts.setStartHandler(() {
      setState(() {
        _isSpeaking = true;
      });
    });

    _flutterTts.setCompletionHandler(() {
      setState(() {
        _isSpeaking = false;
      });
    });

    _flutterTts.setErrorHandler((msg) {
      setState(() {
        _isSpeaking = false;
      });
    });
  }

  Future<String> _detectLanguage(String text) async {
    try {
      String langCode = await langdetect.detect(text);
      return _getTtsLanguageCode(langCode) ?? "en-US";
    } catch (e) {
      // Default to English if detection fails
      return "en-US";
    }
  }

  String? _getTtsLanguageCode(String langCode) {
    // Map detected language codes to supported TTS languages
    switch (langCode) {
      case 'en':
        return 'en-US';
      case 'es':
        return 'es-ES';
      case 'fr':
        return 'fr-FR';
      case 'de':
        return 'de-DE';
      case 'it':
        return 'it-IT';
      case 'pt':
        return 'pt-BR';
      case 'ru':
        return 'ru-RU';
      case 'ja':
        return 'ja-JP';
      case 'ko':
        return 'ko-KR';
      case 'zh':
        return 'zh-CN';
      case 'ar':
        return 'ar-SA';
      case 'hi':
        return 'hi-IN';
      default:
        return 'en-US'; // Default fallback
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wordId = widget.exercise['wordId'] ?? '';
    final word = widget.exercise['word'] ?? '';
    final translation = widget.exercise['translation'] ?? '';
    final phonetic = widget.exercise['phonetic'] ?? '';
    final partOfSpeech = widget.exercise['partOfSpeech'] ?? '';
    final visualAid = widget.exercise['visualAid'] as String?;
    final contextSentence = widget.exercise['contextSentence'] ?? '';
    final contextTranslation = widget.exercise['contextTranslation'] ?? '';
    final audioUrl = widget.exercise['audioUrl'] as String?;
    final useTTS = widget.exercise['useTTS'] as bool? ?? false;

    final words = <Map<String, dynamic>>[
      {
        'wordId': wordId,
        'word': word,
        'translation': translation,
        'phonetic': phonetic,
        'partOfSpeech': partOfSpeech,
        'visualAid': visualAid,
        'contextSentence': contextSentence,
        'contextTranslation': contextTranslation,
        'audioUrl': audioUrl,
        'useTTS': useTTS,
      }
    ];

    // Get theme data
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: widget.categoryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.categoryColor.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(
                    Icons.school_rounded,
                    color: widget.categoryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Introduction',
                    style: textTheme.titleMedium?.copyWith(
                      color: widget.categoryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              widget.exercise['title'] ?? '',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // Instructions
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                widget.exercise['instructions'] ?? '',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Page view
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: words.length,
                itemBuilder: (context, index) {
                  final item = words[index];
                  return _buildWordCard(item, theme, colorScheme, textTheme);
                },
              ),
            ),

            // Page indicators
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                words.length,
                    (index) => Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: index == _currentPage
                        ? widget.categoryColor
                        : colorScheme.outline.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: index == _currentPage
                          ? widget.categoryColor
                          : colorScheme.outline,
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (_currentPage > 0)
                  Expanded(
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: widget.categoryColor.withOpacity(0.5),
                        ),
                      ),
                      child: TextButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: TextButton.styleFrom(
                          backgroundColor: colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Previous',
                          style: textTheme.labelLarge?.copyWith(
                            color: widget.categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_currentPage > 0) const SizedBox(width: 12),
                Expanded(
                  flex: _currentPage > 0 ? 2 : 3,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: widget.categoryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _currentPage == words.length - 1
                          ? () {
                        setState(() {
                          _isComplete = true;
                        });
                        widget.onComplete();
                      }
                          : () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.categoryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _currentPage == words.length - 1 ? 'Complete' : 'Next',
                        style: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWordCard(
      Map<String, dynamic> item,
      ThemeData theme,
      ColorScheme colorScheme,
      TextTheme textTheme,
      ) {
    final word = item['word'] ?? '';
    final translation = item['translation'] ?? '';
    final phonetic = item['phonetic'] ?? '';
    final partOfSpeech = item['partOfSpeech'] ?? '';
    final visualAid = item['visualAid'] as String?;
    final contextSentence = item['contextSentence'] ?? '';
    final contextTranslation = item['contextTranslation'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main word card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Word and phonetic
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      word,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _speak(word),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.categoryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isSpeaking ? Icons.pause : Icons.play_arrow,
                        color: widget.categoryColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (phonetic.isNotEmpty)
                Text(
                  phonetic,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              const SizedBox(height: 16),

              // Part of speech
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: widget.categoryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  partOfSpeech.toUpperCase(),
                  style: textTheme.labelSmall?.copyWith(
                    color: widget.categoryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Translation
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: widget.categoryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  translation,
                  style: textTheme.titleLarge?.copyWith(
                    color: widget.categoryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Visual aid
        if (visualAid != null && visualAid.isNotEmpty)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                visualAid,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),

        if (visualAid != null && visualAid.isNotEmpty)
          const SizedBox(height: 24),

        // Context sentence
        if (contextSentence.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Example:',
                      style: textTheme.titleSmall?.copyWith(
                        color: widget.categoryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => _speak(contextSentence),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.categoryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isSpeaking ? Icons.pause : Icons.play_arrow,
                          color: widget.categoryColor,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  contextSentence,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurface,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  contextTranslation,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface.withOpacity(0.7),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}