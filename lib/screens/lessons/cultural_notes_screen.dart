// lib/screens/lessons/cultural_notes_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CulturalNotesScreen extends StatelessWidget {
  final Map<String, dynamic> culturalNote;
  final Color categoryColor;
  final VoidCallback onContinue;

  const CulturalNotesScreen({
    super.key,
    required this.culturalNote,
    required this.categoryColor,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final title = culturalNote['title'] ?? '';
    final content = culturalNote['content'] ?? '';
    final imageUrl = culturalNote['imageUrl'] as String?;
    final type = culturalNote['type'] ?? '';

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
                      color: categoryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getIconForType(type),
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      type.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: categoryColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 16),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            imageUrl,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        content,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          height: 1.6,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Continue button
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: categoryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Continue',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'history':
        return Icons.history_rounded;
      case 'culture':
        return Icons.local_florist_rounded;
      case 'tradition':
        return Icons.sentiment_very_satisfied_rounded;
      case 'custom':
        return Icons.people_alt_rounded;
      case 'language':
        return Icons.language_rounded;
      case 'etiquette':
        return Icons.sentiment_satisfied_alt_rounded;
      case 'food':
        return Icons.restaurant_rounded;
      case 'festival':
        return Icons.event_rounded;
      default:
        return Icons.info_rounded;
    }
  }
}