// lib/screens/learning_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LearningScreen extends StatelessWidget {
  final String nativeLangCode;
  final String targetLangCode;

  const LearningScreen({
    super.key,
    required this.nativeLangCode,
    required this.targetLangCode,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Learning',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3f37c9),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Path: ${nativeLangCode.toUpperCase()} → ${targetLangCode.toUpperCase()}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF6c757d),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.builder(
              itemCount: 6,
              itemBuilder: (context, index) {
                return Card(
                  elevation: 2,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(
                        0xFF4361ee,
                      ).withOpacity(0.12),
                      child: Icon(
                        Icons.volunteer_activism,
                        color: const Color(0xFF4361ee),
                      ),
                    ),
                    title: Text(
                      'Lesson ${index + 1}',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Short phrase practice and listening',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                    trailing: Icon(
                      Icons.chevron_right,
                      color: const Color(0xFF4361ee),
                    ),
                    onTap: () {},
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
