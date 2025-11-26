// lib/screens/lessons/listening_lesson.dart
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';

class ListeningLesson extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final String? targetLangCode;
  final String? nativeLangCode;
  final VoidCallback? onComplete;

  const ListeningLesson({
    super.key,
    required this.lesson,
    this.targetLangCode,
    this.nativeLangCode,
    this.onComplete,
  });

  @override
  State<ListeningLesson> createState() => _ListeningLessonState();
}

class _ListeningLessonState extends State<ListeningLesson>
    with SingleTickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();

  // Exercise data
  String? _audioText;
  String? _correctAnswer;
  String? _instructions;
  String? _question;
  String? _title;
  List<String> _options = [];
  double _speed = 1.0;

  // State management
  String? _selectedAnswer;
  bool _hasSubmitted = false;
  bool _isCorrect = false;
  bool _isPlaying = false;
  bool _isTtsInitialized = false;
  int _playCount = 0;

  // Animation
  late AnimationController _feedbackController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _parseExerciseData();
    _initializeTts();
  }

  void _initializeAnimations() {
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _feedbackController,
        curve: Curves.easeOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _feedbackController,
        curve: Curves.easeIn,
      ),
    );
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setSharedInstance(true);

      // iOS specific settings
      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      // Set language
      await _flutterTts.setLanguage(widget.targetLangCode ?? 'en');

      // Set speech parameters for natural sound
      await _flutterTts.setSpeechRate(_speed * 0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      // Handlers
      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isPlaying = true);
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _playCount++;
          });
        }
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        if (mounted) setState(() => _isPlaying = false);
      });

      setState(() => _isTtsInitialized = true);

      // Auto-play after a short delay
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted && !_hasSubmitted) _playAudio();
      });
    } catch (e) {
      debugPrint('TTS Initialization Error: $e');
    }
  }

  void _parseExerciseData() {
    _audioText = widget.lesson['audioText'] as String?;
    _correctAnswer = widget.lesson['correctAnswer'] as String?;
    _instructions = widget.lesson['instructions'] as String?;
    _question = widget.lesson['question'] as String?;
    _title = widget.lesson['title'] as String?;

    final optionsList = widget.lesson['options'] as List?;
    if (optionsList != null) {
      _options = optionsList.map((e) => e.toString()).toList();
    }

    // Parse speed
    final speedStr = widget.lesson['speed'] as String?;
    _speed = switch (speedStr?.toLowerCase()) {
      'slow' => 0.7,
      'fast' => 1.3,
      _ => 1.0,
    };
  }

  Future<void> _playAudio() async {
    if (_audioText == null || _audioText!.isEmpty || !_isTtsInitialized) return;

    if (_isPlaying) {
      await _flutterTts.stop();
      return;
    }

    try {
      await _flutterTts.setLanguage(widget.targetLangCode ?? 'en');
      await _flutterTts.setSpeechRate(_speed * 0.45);
      await _flutterTts.speak(_audioText!);
    } catch (e) {
      debugPrint('TTS Speak Error: $e');
    }
  }

  void _onOptionSelected(String option) {
    if (_hasSubmitted) return;
    setState(() => _selectedAnswer = option);
  }

  Future<void> _onSubmit() async {
    if (_selectedAnswer == null || _hasSubmitted) return;

    setState(() {
      _hasSubmitted = true;
      _isCorrect = _selectedAnswer == _correctAnswer;
    });

    _feedbackController.forward();

    if (_isCorrect) {
      // Show success dialog
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) {
        await _showSuccessDialog();
      }
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SuccessDialog(
        audioText: _audioText ?? '',
        correctAnswer: _correctAnswer ?? '',
        targetLangCode: widget.targetLangCode ?? 'en',
        nativeLangCode: widget.nativeLangCode ?? 'en',
        onClose: () {
          Navigator.of(context).pop();
          if (widget.onComplete != null) {
            widget.onComplete!();
          }
        },
      ),
    );
  }

  void _onTryAgain() {
    setState(() {
      _selectedAnswer = null;
      _hasSubmitted = false;
      _isCorrect = false;
    });
    _feedbackController.reset();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Title
                    if (_title != null) ...[
                      Text(
                        _title!,
                        style: theme.textTheme.headlineMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Instructions
                    if (_instructions != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.15),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _instructions!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Audio Player
                    _buildAudioPlayer(theme, colorScheme),
                    const SizedBox(height: 24),

                    // Question
                    if (_question != null) ...[
                      Text(
                        _question!,
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Options
                    ..._buildOptions(theme, colorScheme),

                    // Feedback (only for incorrect answers)
                    if (_hasSubmitted && !_isCorrect) ...[
                      const SizedBox(height: 20),
                      _buildFeedback(theme, colorScheme),
                    ],
                  ],
                ),
              ),
            ),

            // Action Button
            _buildActionButton(theme, colorScheme),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioPlayer(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.12),
            colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Play Button
          GestureDetector(
            onTap: _isTtsInitialized ? _playAudio : null,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: colorScheme.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  _isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                  color: Colors.white,
                  size: 36,
                  key: ValueKey(_isPlaying),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Status Text
          Text(
            _isPlaying ? 'Playing...' : 'Tap to listen',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.primary,
            ),
          ),

          // Speed & Play Count Row
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.speed_rounded,
                      size: 14,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _getSpeedLabel(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              if (_playCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.replay_rounded,
                        size: 14,
                        color: colorScheme.onSurface.withOpacity(0.7),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_playCount',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _getSpeedLabel() {
    if (_speed < 0.8) return 'Slow';
    if (_speed > 1.2) return 'Fast';
    return 'Normal';
  }

  List<Widget> _buildOptions(ThemeData theme, ColorScheme colorScheme) {
    return _options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isSelected = _selectedAnswer == option;
      final isCorrectOption = option == _correctAnswer;
      final showResult = _hasSubmitted;

      Color backgroundColor;
      Color borderColor;
      Color textColor;
      IconData? icon;

      if (showResult) {
        if (isCorrectOption) {
          backgroundColor = const Color(0xFFE8F5E9);
          borderColor = const Color(0xFF4CAF50);
          textColor = const Color(0xFF2E7D32);
          icon = Icons.check_circle_rounded;
        } else if (isSelected) {
          backgroundColor = const Color(0xFFFFEBEE);
          borderColor = const Color(0xFFE57373);
          textColor = const Color(0xFFC62828);
          icon = Icons.cancel_rounded;
        } else {
          backgroundColor = colorScheme.surfaceVariant.withOpacity(0.5);
          borderColor = colorScheme.outline.withOpacity(0.3);
          textColor = colorScheme.onSurface.withOpacity(0.5);
        }
      } else if (isSelected) {
        backgroundColor = colorScheme.primary.withOpacity(0.08);
        borderColor = colorScheme.primary;
        textColor = colorScheme.primary;
      } else {
        backgroundColor = colorScheme.surface;
        borderColor = colorScheme.outline.withOpacity(0.25);
        textColor = colorScheme.onSurface;
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onOptionSelected(option),
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Number Badge
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: (isSelected || (showResult && isCorrectOption))
                          ? borderColor
                          : colorScheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: (isSelected || (showResult && isCorrectOption))
                            ? Colors.white
                            : colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Option Text
                  Expanded(
                    child: Text(
                      option,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),

                  // Result Icon
                  if (showResult && icon != null) ...[
                    const SizedBox(width: 8),
                    Icon(icon, color: borderColor, size: 24),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  Widget _buildFeedback(ThemeData theme, ColorScheme colorScheme) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3E0),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFFF9800),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: const Color(0xFFFF9800),
                size: 40,
              ),
              const SizedBox(height: 10),
              Text(
                'Not quite right',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Correct answer:',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _correctAnswer ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2E7D32),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: _hasSubmitted && !_isCorrect
            ? ElevatedButton.icon(
          onPressed: _onTryAgain,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF9800),
            minimumSize: const Size.fromHeight(56),
          ),
        )
            : ElevatedButton(
          onPressed: _selectedAnswer != null && !_hasSubmitted ? _onSubmit : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          child: const Text('Check Answer'),
        ),
      ),
    );
  }
}

// Success Dialog Widget
class _SuccessDialog extends StatefulWidget {
  final String audioText;
  final String correctAnswer;
  final String targetLangCode;
  final String nativeLangCode;
  final VoidCallback onClose;

  const _SuccessDialog({
    required this.audioText,
    required this.correctAnswer,
    required this.targetLangCode,
    required this.nativeLangCode,
    required this.onClose,
  });

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingTarget = false;
  bool _isPlayingNative = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimation();
    _initializeTts();
    _playBothAudios();
  }

  void _initializeAnimation() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.elasticOut,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5),
      ),
    );

    _animationController.forward();
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.45);

      _flutterTts.setStartHandler(() {
        // Handle start if needed
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) {
          setState(() {
            _isPlayingTarget = false;
            _isPlayingNative = false;
          });
        }
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error in Dialog: $msg');
        if (mounted) {
          setState(() {
            _isPlayingTarget = false;
            _isPlayingNative = false;
          });
        }
      });
    } catch (e) {
      debugPrint('TTS Initialization Error in Dialog: $e');
    }
  }

  Future<void> _playBothAudios() async {
    // Play target language first
    await _playTargetAudio();

    // Wait a bit between
    await Future.delayed(const Duration(milliseconds: 500));

    // Then play native language
    if (mounted) {
      await _playNativeAudio();
    }
  }

  Future<void> _playTargetAudio() async {
    if (widget.audioText.isEmpty) return;

    try {
      setState(() => _isPlayingTarget = true);
      await _flutterTts.setLanguage(widget.targetLangCode);
      await _flutterTts.speak(widget.audioText);

      // Wait for completion
      await Future.delayed(const Duration(milliseconds: 100));
      while (_isPlayingTarget && mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } catch (e) {
      debugPrint('Error playing target audio: $e');
      if (mounted) setState(() => _isPlayingTarget = false);
    }
  }

  Future<void> _playNativeAudio() async {
    if (widget.correctAnswer.isEmpty) return;

    try {
      setState(() => _isPlayingNative = true);
      await _flutterTts.setLanguage(widget.nativeLangCode);
      await _flutterTts.speak(widget.correctAnswer);
    } catch (e) {
      debugPrint('Error playing native audio: $e');
      if (mounted) setState(() => _isPlayingNative = false);
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    size: 48,
                    color: Color(0xFF4CAF50),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Perfect! 🎉',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 24),

                // Target Language (Audio Text)
                _buildAudioCard(
                  theme: theme,
                  colorScheme: colorScheme,
                  text: widget.audioText,
                  isPlaying: _isPlayingTarget,
                  onTap: _playTargetAudio,
                  label: 'Target Language',
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),

                // Native Language (Correct Answer)
                _buildAudioCard(
                  theme: theme,
                  colorScheme: colorScheme,
                  text: widget.correctAnswer,
                  isPlaying: _isPlayingNative,
                  onTap: _playNativeAudio,
                  label: 'Translation',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 24),

                // Continue Button
                ElevatedButton(
                  onPressed: widget.onClose,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(56),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAudioCard({
    required ThemeData theme,
    required ColorScheme colorScheme,
    required String text,
    required bool isPlaying,
    required VoidCallback onTap,
    required String label,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Play Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPlaying ? Icons.stop_rounded : Icons.volume_up_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),

                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        text,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}