// lib/screens/dictionary_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DictionaryScreen extends StatefulWidget {
  final User user;
  final String nativeLangCode;
  final String targetLangCode;

  const DictionaryScreen({
    super.key,
    required this.user,
    required this.nativeLangCode,
    required this.targetLangCode,
  });

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  String _query = '';
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _learnedWords = [];

  @override
  void initState() {
    super.initState();
    _loadLearnedWords();
  }

  Future<void> _loadLearnedWords() async {
    setState(() {
      _loading = true;
      _error = null;
      _learnedWords = [];
    });

    try {
      final progressDoc = await FirebaseFirestore.instance
          .collection('userProgress')
          .doc(widget.user.uid)
          .get();

      if (!progressDoc.exists) {
        setState(() {
          _loading = false;
        });
        return;
      }

      final data = progressDoc.data() ?? {};
      final completed =
          (data['completedWords'] as List<dynamic>?)?.cast<String>() ?? [];

      if (completed.isEmpty) {
        setState(() {
          _loading = false;
        });
        return;
      }

      // Fetch each word by document id (assuming completedWords stores doc ids)
      final futures = completed.map((id) async {
        final doc = await FirebaseFirestore.instance
            .collection('words')
            .doc(id)
            .get();
        if (doc.exists) {
          final d = doc.data() as Map<String, dynamic>;
          // Only include active words
          if (d['isActive'] == false) return null;
          return {'id': doc.id, ...d};
        }
        return null;
      }).toList();

      final results = await Future.wait(futures);
      final words = results.whereType<Map<String, dynamic>>().toList();

      setState(() {
        _learnedWords = words;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _learnedWords.where((w) {
      final translations = (w['translations'] as Map<String, dynamic>?) ?? {};
      final nativeText =
          (translations[widget.nativeLangCode] ??
                  translations.values.firstWhere((_) => true, orElse: () => ''))
              .toString();
      final targetText = (translations[widget.targetLangCode] ?? '').toString();
      final q = _query.toLowerCase();
      return nativeText.toLowerCase().contains(q) ||
          targetText.toLowerCase().contains(q);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            'Dictionary',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF3f37c9),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search learned words',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Text(
                      'Error: $_error',
                      style: GoogleFonts.poppins(color: Colors.red),
                    ),
                  )
                : _learnedWords.isEmpty
                ? Center(
                    child: Text(
                      'You have not learned any words yet.',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6c757d),
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      'No matches',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6c757d),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final w = filtered[index];
                      final translations =
                          (w['translations'] as Map<String, dynamic>?) ?? {};
                      final nativeText =
                          (translations[widget.nativeLangCode] ??
                                  translations.values.firstWhere(
                                    (_) => true,
                                    orElse: () => '',
                                  ))
                              .toString();
                      final targetText =
                          (translations[widget.targetLangCode] ?? '')
                              .toString();

                      return ListTile(
                        title: Text(
                          nativeText,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          targetText.isNotEmpty ? targetText : '—',
                          style: GoogleFonts.poppins(fontSize: 13),
                        ),
                        trailing: Icon(
                          Icons.volume_up,
                          color: const Color(0xFF4361ee),
                        ),
                        onTap: () {},
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
