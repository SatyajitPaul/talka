// // lib/screens/lesson_screen.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';
//
// // Import all lesson type widgets (create these as placeholders if not done)
// import 'lessons/description_lesson.dart';
// import 'lessons/blanks_lesson.dart';
// import 'lessons/mcq_lesson.dart';
//
// import 'lessons/explanation_lesson.dart';
// import 'lessons/selection_lesson.dart';
// import 'lessons/multichoices_lesson.dart';
// import 'lessons/match_lesson.dart';
// import 'lessons/multimatch_lesson.dart';
// import 'lessons/listen_lesson.dart';
// import 'lessons/speak_lesson.dart';
//
// class LessonScreen extends StatefulWidget {
//   final String categoryId;
//   final String subCategoryId;
//   final String nativeLangCode;
//   final String targetLangCode;
//
//   const LessonScreen({
//     super.key,
//     required this.categoryId,
//     required this.subCategoryId,
//     required this.nativeLangCode,
//     required this.targetLangCode,
//   });
//
//   @override
//   State<LessonScreen> createState() => _LessonScreenState();
// }
//
// class _LessonScreenState extends State<LessonScreen> {
//   late Future<List<Map<String, dynamic>>> _lessonsFuture;
//   int _currentIndex = 0;
//   Set<String> _completedLessonIds = {};
//   bool _isLoading = true;
//
//   @override
//   void initState() {
//     super.initState();
//     _lessonsFuture = _loadLessons();
//   }
//
//   Future<List<Map<String, dynamic>>> _loadLessons() async {
//     final uid = FirebaseAuth.instance.currentUser!.uid;
//     final prefs = await SharedPreferences.getInstance();
//     final completedKey = 'completed_lessons_$uid';
//     final completedList = prefs.getStringList(completedKey) ?? [];
//     _completedLessonIds = Set<String>.from(completedList);
//
//     final snap = await FirebaseFirestore.instance
//         .collection('lessons')
//         .where('subCategoryId', isEqualTo: widget.subCategoryId)
//         .where('isActive', isEqualTo: true)
//         .orderBy('order', descending: false)
//         .get();
//
//     final lessons = snap.docs
//         .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
//         .toList();
//
//     // Sort just in case (Firestore order should be sufficient)
//     lessons.sort((a, b) {
//       final orderA = (a['order'] as int?) ?? 0;
//       final orderB = (b['order'] as int?) ?? 0;
//       return orderA.compareTo(orderB);
//     });
//
//     if (mounted) setState(() => _isLoading = false);
//     return lessons;
//   }
//
//   Future<void> _markCompleted(String lessonId) async {
//     if (_completedLessonIds.contains(lessonId)) return;
//
//     setState(() {
//       _completedLessonIds.add(lessonId);
//     });
//
//     final uid = FirebaseAuth.instance.currentUser!.uid;
//     final prefs = await SharedPreferences.getInstance();
//     final completedKey = 'completed_lessons_$uid';
//     await prefs.setStringList(completedKey, _completedLessonIds.toList());
//   }
//
//   void _navigateTo(int index, List<Map<String, dynamic>> lessons) {
//     if (index < 0 || index >= lessons.length || index == _currentIndex) return;
//     if (mounted) {
//       setState(() => _currentIndex = index);
//     }
//   }
//
//   void _goToNext(List<Map<String, dynamic>> lessons) {
//     if (_currentIndex < lessons.length - 1) {
//       _navigateTo(_currentIndex + 1, lessons);
//     } else {
//       _showCompletion();
//     }
//   }
//
//   Future<void> _resetProgress() async {
//     final shouldReset = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Reset Progress?'),
//         content: const Text('This will clear your progress for this topic.'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(false),
//             child: const Text('Cancel'),
//           ),
//           ElevatedButton(
//             style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
//             onPressed: () => Navigator.of(ctx).pop(true),
//             child: const Text('Reset', style: TextStyle(color: Colors.white)),
//           ),
//         ],
//       ),
//     );
//     if (shouldReset == true) {
//       final uid = FirebaseAuth.instance.currentUser!.uid;
//       final prefs = await SharedPreferences.getInstance();
//       final completedKey = 'completed_lessons_$uid';
//
//       // Keep completions from OTHER subcategories
//       final allLessons = await _lessonsFuture;
//       final currentLessonIds = Set<String>.from(allLessons.map((l) => l['id'] as String));
//       final filtered = _completedLessonIds.where((id) => !currentLessonIds.contains(id)).toList();
//
//       await prefs.setStringList(completedKey, filtered);
//       if (mounted) {
//         setState(() {
//           _completedLessonIds = Set.from(filtered);
//           _currentIndex = 0;
//         });
//       }
//     }
//   }
//
//   Future<void> _cancelLesson() async {
//     final shouldCancel = await showDialog<bool>(
//       context: context,
//       builder: (ctx) => AlertDialog(
//         title: const Text('Exit Lesson?'),
//         content: const Text('Your progress will be saved. Are you sure?'),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.of(ctx).pop(false),
//             child: const Text('Stay'),
//           ),
//           ElevatedButton(
//             onPressed: () => Navigator.of(ctx).pop(true),
//             child: const Text('Exit'),
//           ),
//         ],
//       ),
//     );
//     if (shouldCancel == true) {
//       if (!mounted) return;
//       // Pop until LearningScreen (assuming it's in the stack)
//       Navigator.of(context).pop();
//     }
//   }
//
//   void _showCompletion() {
//     ScaffoldMessenger.of(context).showSnackBar(
//       SnackBar(
//         content: Row(
//           children: [
//             Icon(Icons.check_circle, color: Colors.white),
//             const SizedBox(width: 12),
//             const Text('All lessons completed! 🎉'),
//           ],
//         ),
//         backgroundColor: Theme.of(context).colorScheme.primary,
//         duration: const Duration(seconds: 3),
//       ),
//     );
//     // Return to LearningScreen
//     Navigator.of(context).pop();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final colorScheme = Theme.of(context).colorScheme;
//
//     return WillPopScope(
//       onWillPop: () async {
//         _cancelLesson();
//         return false; // Prevent default back behavior
//       },
//       child: Scaffold(
//         backgroundColor: colorScheme.background,
//         appBar: AppBar(
//           backgroundColor: Colors.transparent,
//           elevation: 0,
//           leading: IconButton(
//             icon: const Icon(Icons.arrow_back),
//             onPressed: _cancelLesson,
//           ),
//           title: Text('Lesson ${_currentIndex + 1}'),
//           actions: [
//             IconButton(
//               icon: const Icon(Icons.refresh),
//               onPressed: _resetProgress,
//               tooltip: 'Reset progress',
//             ),
//           ],
//         ),
//         body: FutureBuilder<List<Map<String, dynamic>>>(
//           future: _lessonsFuture,
//           builder: (context, snapshot) {
//             if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
//               return const Center(child: CircularProgressIndicator());
//             }
//             if (!snapshot.hasData || snapshot.data!.isEmpty) {
//               return Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(Icons.book_online_outlined, size: 64, color: Colors.grey),
//                     const SizedBox(height: 16),
//                     Text(
//                       'No lessons available for this topic.',
//                       style: Theme.of(context).textTheme.bodyLarge,
//                       textAlign: TextAlign.center,
//                     ),
//                   ],
//                 ),
//               );
//             }
//
//             final lessons = snapshot.data!;
//             final currentLesson = lessons[_currentIndex];
//
//             Widget lessonWidget;
//             final lessonType = (currentLesson['type'] as String?)?.toLowerCase();
//
//             switch (lessonType) {
//               case 'description':
//                 lessonWidget = DescriptionLesson(lesson: currentLesson,
//                   nativeLangCode: widget.nativeLangCode,
//                   targetLangCode: widget.targetLangCode,);
//                 break;
//               case 'explanation':
//                 lessonWidget = ExplanationLesson(lesson: currentLesson);
//                 break;
//               case 'selection':
//                 lessonWidget = SelectionLesson(
//                   lesson: currentLesson,
//                   onComplete: () => _markCompleted(currentLesson['id']),
//                 );
//                 break;
//               case 'blanks':
//                 lessonWidget = BlanksLesson(
//                   lesson: currentLesson,
//                   onComplete: () => _markCompleted(currentLesson['id']),
//                 );
//                 break;
//               case 'mcq':
//                 lessonWidget = MCQLesson(
//                   lesson: currentLesson,
//                   onComplete: () => _markCompleted(currentLesson['id']),
//                 );
//                 break;
//               case 'multichoices':
//                 lessonWidget = MultiChoicesLesson(
//                   lesson: currentLesson,
//                   onComplete: () => _markCompleted(currentLesson['id']),
//                 );
//                 break;
//               case 'match':
//                 lessonWidget = MatchLesson(
//                   lesson: currentLesson,
//                   onComplete: () => _markCompleted(currentLesson['id']),
//                 );
//                 break;
//               case 'multimatch':
//                 lessonWidget = MultiMatchLesson(
//                   lesson: currentLesson,
//                   onComplete: () => _markCompleted(currentLesson['id']),
//                 );
//                 break;
//               case 'listen':
//                 lessonWidget = ListenLesson(
//                   lesson: currentLesson,
//                   onComplete: () => _markCompleted(currentLesson['id']),
//                 );
//                 break;
//               case 'speak':
//                 lessonWidget = SpeakLesson(
//                   lesson: currentLesson,
//                   onComplete: () => _markCompleted(currentLesson['id']),
//                 );
//                 break;
//               default:
//                 lessonWidget = Center(
//                   child: Text('Unsupported lesson type: $lessonType'),
//                 );
//             }
//
//             return Column(
//               children: [
//                 Expanded(child: lessonWidget),
//                 _buildNavigationButtons(lessons),
//               ],
//             );
//           },
//         ),
//       ),
//     );
//   }
//
//   Widget _buildNavigationButtons(List<Map<String, dynamic>> lessons) {
//     final colorScheme = Theme.of(context).colorScheme;
//     return Padding(
//       padding: const EdgeInsets.all(16.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           OutlinedButton.icon(
//             onPressed: _currentIndex > 0
//                 ? () => _navigateTo(_currentIndex - 1, lessons)
//                 : null,
//             icon: const Icon(Icons.arrow_back),
//             label: const Text('Previous'),
//             style: OutlinedButton.styleFrom(
//               foregroundColor: colorScheme.primary,
//               side: BorderSide(color: colorScheme.primary),
//             ),
//           ),
//           ElevatedButton.icon(
//             onPressed: () => _goToNext(lessons),
//             icon: const Icon(Icons.arrow_forward),
//             label: Text(_currentIndex == lessons.length - 1 ? 'Finish' : 'Next'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: colorScheme.primary,
//               foregroundColor: Colors.white,
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }