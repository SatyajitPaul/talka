// lib/screens/speak_lesson.dart

import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';

class SpeakLesson extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final String? targetLangCode;
  final String? nativeLangCode;
  final VoidCallback? onComplete;

  const SpeakLesson({
    super.key,
    required this.lesson,
    this.targetLangCode,
    this.nativeLangCode,
    this.onComplete,
  });

  @override
  State<SpeakLesson> createState() => _SpeakLessonState();
}

class _SpeakLessonState extends State<SpeakLesson>
    with SingleTickerProviderStateMixin {
  late FlutterTts _flutterTts;
  late SpeechToText _speechToText;

  // Exercise data
  String? _targetSentence;
  String? _expectedAnswer;
  List<String>? _alternativeAnswers;
  String? _prompt;
  String? _instructions;
  String? _title;
  List<String>? _hints;
  String? _pronunciationTips;
  int _maxRetries = 3;

  // Speech & TTS state
  bool _isListening = false;
  bool _hasMicrophonePermission = false;
  bool _isCheckingPermission = false;
  bool _hasSubmitted = false;
  bool _isCorrect = false;
  String _spokenText = '';
  String _feedback = '';
  int _attempts = 0;
  bool _isTtsInitialized = false;
  bool _isPlayingPrompt = false;
  bool _showHints = false;

  // Animations
  late AnimationController _feedbackController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _parseExerciseData();
    _initTts();
    requestMicPermission();
    _initSpeechToText();
  }

  void _initializeAnimations() {
    _feedbackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.easeOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _feedbackController, curve: Curves.easeIn),
    );
  }

  Future<void> requestMicPermission() async {
    var status = await Permission.microphone.status;

    if (status.isDenied) {
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      print("Microphone permission granted!");
    } else if (status.isPermanentlyDenied) {
      print("Permission permanently denied—open app settings.");
      openAppSettings();
    }
  }
  void _parseExerciseData() {
    _targetSentence = widget.lesson['targetSentence'] as String?;
    _expectedAnswer = widget.lesson['expectedAnswer'] as String?;
    _alternativeAnswers = (widget.lesson['alternativeAnswers'] as List?)
        ?.map((e) => e.toString())
        .toList();
    _prompt = widget.lesson['prompt'] as String?;
    _instructions = widget.lesson['instructions'] as String?;
    _title = widget.lesson['title'] as String?;
    _hints = (widget.lesson['hints'] as List?)
        ?.map((e) => e.toString())
        .toList();
    _pronunciationTips = widget.lesson['pronunciationTips'] as String?;
    _maxRetries = widget.lesson['maxRetries'] as int? ?? 3;
  }

  Future<void> _initTts() async {
    _flutterTts = FlutterTts();
    try {
      await _flutterTts.setSharedInstance(true);

      await _flutterTts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playAndRecord,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
        ],
        IosTextToSpeechAudioMode.voicePrompt,
      );

      await _flutterTts.setLanguage(widget.targetLangCode ?? 'en-US');
      await _flutterTts.setSpeechRate(0.45);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() {
        if (mounted) setState(() => _isPlayingPrompt = true);
      });

      _flutterTts.setCompletionHandler(() {
        if (mounted) setState(() => _isPlayingPrompt = false);
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('TTS Error: $msg');
        if (mounted) setState(() => _isPlayingPrompt = false);
      });

      setState(() => _isTtsInitialized = true);
    } catch (e) {
      debugPrint('TTS Init Error: $e');
    }
  }

  Future<void> _initSpeechToText() async {
    // Initialize speech recognition
    _speechToText = SpeechToText();
    bool initSuccess = await _speechToText.initialize(
      onError: (error) {
        debugPrint('STT Error: ${error.errorMsg}');
        if (mounted) {
          setState(() {
            _isListening = false;
            _feedback = 'Voice recognition failed. Please try again.';
          });
        }
      },
      onStatus: (status) {
        // Optional: handle status changes
      },
    );

    if (mounted) {
      setState(() {
        _hasMicrophonePermission = initSuccess;
      });
    }
  }

  Future<void> _requestMicrophonePermission() async {
    if (_isCheckingPermission) return;
    setState(() => _isCheckingPermission = true);

    try {
      bool hasPermission = await _speechToText.initialize();
      if (mounted) {
        setState(() {
          _hasMicrophonePermission = hasPermission;
          _isCheckingPermission = false;
        });
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
      if (mounted) {
        setState(() {
          _hasMicrophonePermission = false;
          _isCheckingPermission = false;
        });
      }
    }
  }

  Future<void> _speakPrompt() async {
    if (!_isTtsInitialized || _prompt == null) return;
    if (_isPlayingPrompt) {
      await _flutterTts.stop();
      return;
    }
    try {
      await _flutterTts.setLanguage(widget.targetLangCode ?? 'en-US');
      await _flutterTts.speak(_prompt!);
    } catch (e) {
      debugPrint('Speak Prompt Error: $e');
    }
  }

  Future<void> _startListening() async {
    if (_attempts >= _maxRetries || _hasSubmitted) return;

    if (!_hasMicrophonePermission) {
      await _requestMicrophonePermission();
      return;
    }

    setState(() {
      _isListening = true;
      _spokenText = '';
      _feedback = '';
    });

    try {
      await _speechToText.listen(
        onResult: _onSpeechResult,
        localeId: _getLocaleId(),
        pauseFor: const Duration(seconds: 2),
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('Listen Error: $e');
      if (mounted) setState(() => _isListening = false);
    }
  }

  String _getLocaleId() {
    switch (widget.targetLangCode) {
      case 'es':
        return 'es-ES';
      case 'ta':
        return 'ta-IN';
      case 'en':
        return 'en-US';
      default:
        return 'en-US';
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    String text = result.recognizedWords.trim();
    setState(() {
      _spokenText = text;
      _isListening = false;
      _attempts++;
      _hasSubmitted = true;
    });

    _evaluateAnswer(text);
  }

  void _evaluateAnswer(String userAnswer) {
    final expected = _expectedAnswer?.toLowerCase() ?? '';
    final alternatives = _alternativeAnswers
        ?.map((e) => e.toLowerCase())
        .toList() ?? [];

    final normalizedUser = _normalize(userAnswer);
    final normalizedExpected = _normalize(expected);
    final normalizedAlts = alternatives.map(_normalize).toList();

    bool correct = normalizedUser == normalizedExpected ||
        normalizedAlts.contains(normalizedUser);

    setState(() {
      _isCorrect = correct;
      _feedback = correct
          ? '✅ Correct!'
          : _attempts >= _maxRetries
          ? '❌ Max attempts reached.'
          : '❌ Not quite. Try again.';
    });

    _feedbackController.forward();

    if (correct) {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) _showSuccessDialog();
      });
    }
  }

  String _normalize(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ').trim();
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _SuccessDialog(
        targetText: _targetSentence ?? '',
        nativeText: _prompt ?? _instructions ?? '',
        targetLangCode: widget.targetLangCode ?? 'en-US',
        nativeLangCode: widget.nativeLangCode ?? 'en-US',
        onClose: () {
          Navigator.of(context).pop();
          widget.onComplete?.call();
        },
      ),
    );
  }

  void _onTryAgain() {
    setState(() {
      _hasSubmitted = false;
      _isCorrect = false;
      _spokenText = '';
      _feedback = '';
      _attempts = 0;
    });
    _feedbackController.reset();
  }

  void _toggleHints() {
    setState(() {
      _showHints = !_showHints;
    });
  }

  Future<void> _speakTargetSentence() async {
    if (!_isTtsInitialized || _targetSentence == null) return;
    try {
      await _flutterTts.setLanguage(widget.targetLangCode ?? 'en-US');
      await _flutterTts.speak(_targetSentence!);
    } catch (e) {
      debugPrint('Speak Target Error: $e');
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _speechToText.stop();
    _feedbackController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isMaxAttempts = _attempts >= _maxRetries;
    final isDisabled = _hasSubmitted || isMaxAttempts;
    final canTapMic = _hasMicrophonePermission && !isDisabled && !_isCheckingPermission;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: Text(_title ?? 'Speaking Exercise'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(_isPlayingPrompt ? Icons.stop : Icons.volume_up),
            onPressed: _isTtsInitialized ? _speakPrompt : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                              Icons.mic_rounded,
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

                    // Prompt
                    if (_prompt != null) ...[
                      Text(
                        _prompt!,
                        style: theme.textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Target Sentence
                    if (_targetSentence != null)
                      GestureDetector(
                        onTap: _isTtsInitialized ? _speakTargetSentence : null,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(0.2),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.volume_up_rounded,
                                color: colorScheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _targetSentence!,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Pronunciation Tips
                    if (_pronunciationTips != null) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            _pronunciationTips!,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Permission Missing UI
                    if (!_hasMicrophonePermission && !_isCheckingPermission) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              Icon(
                                Icons.mic_off_rounded,
                                color: colorScheme.error,
                                size: 48,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Microphone access required',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.error,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please allow microphone access to speak your answer.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 16),
                              OutlinedButton.icon(
                                onPressed: _requestMicrophonePermission,
                                icon: const Icon(Icons.settings),
                                label: const Text('Enable Microphone'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Mic Button
                    ElevatedButton.icon(
                      onPressed: canTapMic ? _startListening : null,
                      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                      label: Text(
                        _isListening
                            ? 'Listening...'
                            : _hasMicrophonePermission
                            ? 'Tap & Speak Clearly'
                            : 'Enable Microphone',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isListening
                            ? Colors.red.withOpacity(0.2)
                            : null,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Spoken Text
                    if (_spokenText.isNotEmpty) ...[
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'You said: $_spokenText',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Feedback (incorrect only)
                    if (_hasSubmitted && !_isCorrect)
                      _buildFeedback(theme, colorScheme),

                    // Hints
                    if (_hints != null && _hints!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _toggleHints,
                        child: Text(
                          _showHints ? 'Hide hints' : 'Need a hint?',
                          style: TextStyle(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (_showHints)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: _hints!.map((hint) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    '• $hint',
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // Bottom Action & Counter
            Container(
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_hasSubmitted && !_isCorrect)
                      ElevatedButton.icon(
                        onPressed: _onTryAgain,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          minimumSize: const Size.fromHeight(56),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Attempt: $_attempts / $_maxRetries',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
                'Almost there!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFE65100),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try to match: $_targetSentence',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===== SUCCESS DIALOG =====
class _SuccessDialog extends StatefulWidget {
  final String targetText;
  final String nativeText;
  final String targetLangCode;
  final String nativeLangCode;
  final VoidCallback onClose;

  const _SuccessDialog({
    required this.targetText,
    required this.nativeText,
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
    _initializeAnimations();
    _initializeTts();
    _playBoth();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
          parent: _animationController, curve: const Interval(0.0, 0.5)),
    );
    _animationController.forward();
  }

  Future<void> _initializeTts() async {
    try {
      await _flutterTts.setSharedInstance(true);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.45);
    } catch (e) {
      debugPrint('TTS Dialog Init Error: $e');
    }
  }

  Future<void> _playBoth() async {
    await _playTarget();
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) await _playNative();
  }

  Future<void> _playTarget() async {
    if (widget.targetText.isEmpty) return;
    setState(() => _isPlayingTarget = true);
    try {
      await _flutterTts.setLanguage(widget.targetLangCode);
      await _flutterTts.speak(widget.targetText);
    } finally {
      if (mounted) setState(() => _isPlayingTarget = false);
    }
  }

  Future<void> _playNative() async {
    if (widget.nativeText.isEmpty) return;
    setState(() => _isPlayingNative = true);
    try {
      await _flutterTts.setLanguage(widget.nativeLangCode);
      await _flutterTts.speak(widget.nativeText);
    } finally {
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
                Text(
                  'Perfect! 🎉',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(height: 24),
                _buildAudioCard(
                  theme: theme,
                  colorScheme: colorScheme,
                  text: widget.targetText,
                  isPlaying: _isPlayingTarget,
                  onTap: _playTarget,
                  label: 'What you should say',
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 12),
                _buildAudioCard(
                  theme: theme,
                  colorScheme: colorScheme,
                  text: widget.nativeText,
                  isPlaying: _isPlayingNative,
                  onTap: _playNative,
                  label: 'Meaning',
                  color: const Color(0xFF4CAF50),
                ),
                const SizedBox(height: 24),
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