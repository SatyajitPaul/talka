// lib/screens/lessons/focus_sentences_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FocusSentencesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> focusSentences;
  final Color categoryColor;
  final VoidCallback onContinue;

  const FocusSentencesScreen({
    super.key,
    required this.focusSentences,
    required this.categoryColor,
    required this.onContinue,
  });

  @override
  State<FocusSentencesScreen> createState() => _FocusSentencesScreenState();
}

class _FocusSentencesScreenState extends State<FocusSentencesScreen>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentPage = 0;
  late List<AnimationController> _animControllers;
  late List<Animation<double>> _fadeAnimations;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Create animation controllers for each sentence
    _animControllers = List.generate(
      widget.focusSentences.length,
          (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      ),
    );

    _fadeAnimations = _animControllers
        .map((controller) => CurvedAnimation(
      parent: controller,
      curve: Curves.easeOut,
    ))
        .toList();

    // Animate first sentence
    if (_animControllers.isNotEmpty) {
      _animControllers[0].forward();
    }
  }

  void _nextPage() {
    if (_currentPage < widget.focusSentences.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onContinue();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var controller in _animControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: widget.categoryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.format_quote_rounded,
                          color: widget.categoryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Key Sentences',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Master these important phrases',
                              style: textTheme.bodySmall?.copyWith(
                                color:
                                colorScheme.onBackground.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress Indicator
                  Row(
                    children: List.generate(
                      widget.focusSentences.length,
                          (index) => Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(
                            right: index < widget.focusSentences.length - 1
                                ? 8
                                : 0,
                          ),
                          decoration: BoxDecoration(
                            color: index <= _currentPage
                                ? widget.categoryColor
                                : colorScheme.surfaceVariant,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Sentences PageView
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  if (index < _animControllers.length) {
                    _animControllers[index].forward();
                  }
                },
                itemCount: widget.focusSentences.length,
                itemBuilder: (context, index) {
                  return _buildSentenceCard(
                    widget.focusSentences[index],
                    index,
                  );
                },
              ),
            ),

            // Navigation Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _previousPage,
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
                  if (_currentPage > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _nextPage,
                      icon: Icon(
                        _currentPage == widget.focusSentences.length - 1
                            ? Icons.check_rounded
                            : Icons.arrow_forward_rounded,
                      ),
                      label: Text(
                        _currentPage == widget.focusSentences.length - 1
                            ? 'Finish'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: widget.categoryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  Widget _buildSentenceCard(Map<String, dynamic> sentence, int index) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final source = sentence['source'] as String? ?? '';
    final target = sentence['target'] as String? ?? '';
    final phoneticGuide = sentence['phoneticGuide'] as String? ?? '';
    final usageContext = sentence['usageContext'] as String? ?? '';
    final frequency = sentence['frequency'] as String? ?? '';

    return FadeTransition(
      opacity: _fadeAnimations[index],
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Sentence Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    widget.categoryColor.withOpacity(0.15),
                    widget.categoryColor.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: widget.categoryColor.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Target Language
                  Text(
                    source,
                    style: GoogleFonts.poppins(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: widget.categoryColor,
                      height: 1.4,
                    ),
                  ),

                  // Phonetic Guide
                  if (phoneticGuide.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      phoneticGuide,
                      style: textTheme.bodyLarge?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colorScheme.onBackground.withOpacity(0.6),
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),
                  Divider(color: widget.categoryColor.withOpacity(0.3)),
                  const SizedBox(height: 20),

                  // Translation
                  Text(
                    target,
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onBackground,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Frequency Badge
            if (frequency.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _getFrequencyColor(frequency).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getFrequencyColor(frequency).withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getFrequencyIcon(frequency),
                      size: 18,
                      color: _getFrequencyColor(frequency),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Used ${frequency.toLowerCase()}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _getFrequencyColor(frequency),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Usage Context
            if (usageContext.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: widget.categoryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'When to use this',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: widget.categoryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      usageContext,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onBackground.withOpacity(0.8),
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _getFrequencyColor(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'very often':
      case 'often':
        return Colors.green;
      case 'sometimes':
      case 'moderate':
        return Colors.orange;
      case 'rarely':
        return Colors.red;
      default:
        return widget.categoryColor;
    }
  }

  IconData _getFrequencyIcon(String frequency) {
    switch (frequency.toLowerCase()) {
      case 'very often':
      case 'often':
        return Icons.trending_up_rounded;
      case 'sometimes':
      case 'moderate':
        return Icons.show_chart_rounded;
      case 'rarely':
        return Icons.trending_down_rounded;
      default:
        return Icons.analytics_outlined;
    }
  }
}