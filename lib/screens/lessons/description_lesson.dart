// lib/screens/lessons/description_lesson.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

class DescriptionLesson extends StatefulWidget {
  final Map<String, dynamic> lesson;
  final String nativeLangCode;
  final String targetLangCode;

  const DescriptionLesson({
    super.key,
    required this.lesson,
    required this.nativeLangCode,
    required this.targetLangCode,
  });

  @override
  State<DescriptionLesson> createState() => _DescriptionLessonState();
}

class _DescriptionLessonState extends State<DescriptionLesson>
    with TickerProviderStateMixin {
  late FlutterTts _tts;
  bool _canSpeak = false;
  bool _isSpeaking = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initTts();
  }

  @override
  void dispose() {
    _tts.stop();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage(widget.targetLangCode);
      await _tts.setVolume(1.0);
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);

      _tts.setStartHandler(() {
        if (mounted) setState(() => _isSpeaking = true);
      });

      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });

      _tts.setErrorHandler((msg) {
        debugPrint("TTS Error: $msg");
        if (mounted) setState(() => _canSpeak = false);
      });

      if (mounted) {
        setState(() => _canSpeak = true);
        _speak();
      }
    } catch (e) {
      debugPrint("TTS init failed: $e");
      if (mounted) setState(() => _canSpeak = false);
    }
  }

  Future<void> _speak() async {
    final message = _getMessage();
    if (message != null && _canSpeak) {
      await _tts.speak(message);
    }
  }

  String? _getTopicName() {
    final nameMap = widget.lesson['name'] as Map<String, dynamic>?;
    return nameMap?[widget.nativeLangCode]?.toString();
  }

  String? _getMessage() {
    final nativeMap = widget.lesson[widget.nativeLangCode] as Map<String, dynamic>?;
    return nativeMap?[widget.targetLangCode]?.toString();
  }

  String? get _getImageUrl => widget.lesson['imageUrl']?.toString();

  @override
  Widget build(BuildContext context) {
    final topicName = _getTopicName();
    final message = _getMessage();

    if (topicName == null || message == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.translate_outlined, size: 64, color: Colors.cyan),
                const SizedBox(height: 16),
                Text(
                  'This lesson is not available for\n${widget.nativeLangCode} → ${widget.targetLangCode}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: Navigator.of(context).pop,
                  child: const Text('Go Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              // Optional Image (centered)
              if (_getImageUrl != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: CachedNetworkImage(
                      imageUrl: _getImageUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => const AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Icon(Icons.broken_image, size: 64),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Lesson Title + Speaker Icon (right-aligned)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        topicName,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_canSpeak)
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceVariant,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          splashRadius: 24,
                          onPressed: _isSpeaking ? null : _speak,
                          icon: Icon(
                            _isSpeaking
                                ? Icons.volume_up_rounded
                                : Icons.volume_up_outlined,
                            color: _isSpeaking
                                ? colorScheme.secondary
                                : colorScheme.onSurfaceVariant,
                            size: 24,
                          ),
                          tooltip: _isSpeaking
                              ? 'Speaking...'
                              : 'Listen to lesson title pronunciation',
                        ),
                      ),
                  ],
                ),
              ),

              const Spacer(),

              // Target Language Message (at bottom)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outlineVariant, width: 1),
                ),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}