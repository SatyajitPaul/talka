// lib/screens/profile_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  final User user;

  const ProfileScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          CircleAvatar(
            radius: 64,
            backgroundColor: const Color(0xFF4361ee).withOpacity(0.12),
            child: CircleAvatar(
              radius: 60,
              backgroundImage: user.photoURL != null
                  ? CachedNetworkImageProvider(user.photoURL!)
                  : null,
              child: user.photoURL == null
                  ? Icon(Icons.person, size: 60, color: const Color(0xFF4361ee))
                  : null,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            user.displayName ?? 'Language Learner',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            user.email ?? '',
            style: GoogleFonts.poppins(color: const Color(0xFF6c757d)),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.language, color: Color(0xFF4361ee)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Learning progress: Beginner',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.verified_user, color: Color(0xFF4361ee)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Account verified',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
