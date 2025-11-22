// lib/screens/learning_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LearningScreen extends StatefulWidget {
  final String nativeLangCode;
  final String targetLangCode;

  const LearningScreen({
    super.key,
    required this.nativeLangCode,
    required this.targetLangCode,
  });

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _categories = [];
  Map<String, List<Map<String, dynamic>>> _subByCat = {};

  @override
  void initState() {
    super.initState();
    _loadCategoriesAndSubcategories();
  }

  Future<void> _loadCategoriesAndSubcategories() async {
    setState(() {
      _loading = true;
      _error = null;
      _categories = [];
      _subByCat = {};
    });

    try {
      final catSnap = await FirebaseFirestore.instance
          .collection('categories')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final subSnap = await FirebaseFirestore.instance
          .collection('subcategories')
          .where('isActive', isEqualTo: true)
          .orderBy('order')
          .get();

      final cats = catSnap.docs
          .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
          .toList();

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final s in subSnap.docs) {
        final m = {'id': s.id, ...s.data() as Map<String, dynamic>};
        final cid = (m['categoryId'] ?? '').toString();
        grouped.putIfAbsent(cid, () => []).add(m);
      }

      setState(() {
        _categories = cats;
        _subByCat = grouped;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _localizedName(Map<String, dynamic>? map) {
    if (map == null) return '';
    try {
      final names = Map<String, dynamic>.from(map);
      return (names[widget.nativeLangCode] ?? names.values.first ?? '')
          .toString();
    } catch (_) {
      return '';
    }
  }

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
          const SizedBox(height: 8),
          Text(
            'Path: ${widget.nativeLangCode.toUpperCase()} → ${widget.targetLangCode.toUpperCase()}',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: const Color(0xFF6c757d),
            ),
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
                : _categories.isEmpty
                ? Center(
                    child: Text(
                      'No categories available',
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF6c757d),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, idx) {
                      final cat = _categories[idx];
                      final catName = _localizedName(
                        cat['name'] as Map<String, dynamic>?,
                      );
                      final subs = _subByCat[cat['id']] ?? [];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF4361ee,
                                      ).withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.folder_open,
                                      color: const Color(0xFF4361ee),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      catName.isNotEmpty ? catName : 'Untitled',
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              subs.isEmpty
                                  ? Text(
                                      'No subtopics',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF6c757d),
                                      ),
                                    )
                                  : Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: subs.map((s) {
                                        final sName = _localizedName(
                                          s['name'] as Map<String, dynamic>?,
                                        );
                                        return ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            elevation: 0,
                                            side: const BorderSide(
                                              color: Color(0xFFe9eefb),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            // For now show subcategory details; in future navigate to lessons
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Open: ${sName.isNotEmpty ? sName : 'Subtopic'}',
                                                ),
                                              ),
                                            );
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                sName.isNotEmpty
                                                    ? sName
                                                    : 'Untitled',
                                                style: GoogleFonts.poppins(
                                                  color: const Color(
                                                    0xFF212529,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.chevron_right,
                                                size: 18,
                                                color: const Color(0xFF4361ee),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                            ],
                          ),
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
