// lib/screens/lessons/introduction_exercise_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    setState(() {
      _currentPage = _pageController.page?.round() ?? 0;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
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

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: widget.categoryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Introduction',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.categoryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                widget.exercise['title'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),

              // Instructions
              Text(
                widget.exercise['instructions'] ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: Colors.grey[600],
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
                    return _buildWordCard(item);
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: index == _currentPage
                          ? widget.categoryColor
                          : Colors.grey.shade300,
                      shape: BoxShape.circle,
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
                      child: OutlinedButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: widget.categoryColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Previous',
                          style: GoogleFonts.poppins(
                            color: widget.categoryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: _currentPage > 0 ? 2 : 3,
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        _currentPage == words.length - 1 ? 'Complete' : 'Next',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWordCard(Map<String, dynamic> item) {
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
            color: widget.categoryColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.categoryColor.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              // Word and phonetic
              Text(
                word,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 8),
              if (phonetic.isNotEmpty)
                Text(
                  phonetic,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              const SizedBox(height: 16),

              // Part of speech
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
                  partOfSpeech.toUpperCase(),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: widget.categoryColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Translation
              Text(
                translation,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: widget.categoryColor,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Visual aid
        if (visualAid != null && visualAid.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              visualAid,
              height: 150,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),

        if (visualAid != null && visualAid.isNotEmpty)
          const SizedBox(height: 24),

        // Context sentence
        if (contextSentence.isNotEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Example:',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  contextSentence,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.grey[800],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  contextTranslation,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}