import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';

// --- Models ---
class Entry {
  final String id;
  String title;
  String content;
  String actualContent;
  final DateTime createdAt;
  int failureCount;
  int? lockoutUntil;

  Entry({
    required this.id,
    required this.title,
    required this.content,
    required this.actualContent,
    required this.createdAt,
    this.failureCount = 0,
    this.lockoutUntil,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'content': content,
    'actualContent': actualContent,
    'createdAt': createdAt.toIso8601String(),
    'failureCount': failureCount,
    'lockoutUntil': lockoutUntil,
  };

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
    id: json['id'],
    title: json['title'],
    content: json['content'],
    actualContent: json['actualContent'],
    createdAt: DateTime.parse(json['createdAt']),
    failureCount: json['failureCount'],
    lockoutUntil: json['lockoutUntil'],
  );
}

// --- Main Application ---
void main() {
  runApp(const UnconfessionalApp());
}

class UnconfessionalApp extends StatelessWidget {
  const UnconfessionalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'The Unconfessional',
      theme: ThemeData(
        primarySwatch: Colors.brown,
        textTheme: GoogleFonts.playfairDisplayTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const ConfessPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// --- Main Page ---
class ConfessPage extends StatefulWidget {
  const ConfessPage({super.key});

  @override
  State<ConfessPage> createState() => _ConfessPageState();
}

class _ConfessPageState extends State<ConfessPage> with SingleTickerProviderStateMixin {
  bool _isSpread = false;
  late AnimationController _controller;
  late Animation<double> _animation;

  // State variables from original app
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _actualContent = "";
  List<Entry> _entries = [];
  bool _isLoaded = false;

  // Scrambling logic
  static const Map<String, List<String>> keyboardRoulette = {
    'a': ['x', 'z', 'q', 'w', 'c', 'v', 'b'], 'b': ['n', 'h', 'g', 'v', 'c', 'f', 'd'],
    'c': ['v', 'f', 'd', 'x', 'z', 's', 'w'], 'd': ['s', 'f', 'e', 'r', 'c', 'x', 'z'],
    'e': ['r', 'w', 's', 'd', 'f', 'q', 'a'], 'f': ['d', 'g', 'r', 't', 'v', 'c', 'x'],
    'g': ['f', 'h', 't', 'y', 'b', 'v', 'c'], 'h': ['g', 'j', 'y', 'u', 'n', 'b', 'v'],
    'i': ['u', 'o', 'k', 'j', 'l', 'p', 'q'], 'j': ['h', 'k', 'u', 'i', 'm', 'n', 'b'],
    'k': ['j', 'l', 'i', 'o', 'n', 'm', 'h'], 'l': ['k', 'p', 'o', 'i', 'm', 'n', 'j'],
    'm': ['n', 'j', 'k', 'l', 'x', 'z', 's'], 'n': ['b', 'm', 'h', 'j', 'v', 'c', 'x'],
    'o': ['i', 'p', 'l', 'k', 'u', 'y', 't'], 'p': ['o', 'l', 'k', 'j', 'i', 'u', 'y'],
    'q': ['w', 'a', 's', 'e', 'r', 't', 'y'], 'r': ['e', 't', 'd', 'f', 'g', 'h', 'j'],
    's': ['a', 'd', 'w', 'e', 'z', 'x', 'c'], 't': ['r', 'y', 'f', 'g', 'h', 'j', 'k'],
    'u': ['y', 'i', 'h', 'j', 'k', 'l', 'o'], 'v': ['c', 'b', 'f', 'g', 'h', 'n', 'm'],
    'w': ['q', 's', 'e', 'r', 'a', 'd', 'f'], 'x': ['z', 'c', 's', 'd', 'f', 'v', 'b'],
    'y': ['t', 'u', 'g', 'h', 'j', 'k', 'l'], 'z': ['x', 's', 'a', 'w', 'q', 'e', 'r'],
    ' ': [' '],
    '.': ['!', '?', ',', ';', ':', '"', "'"], '!': ['.', '?', ',', ';', ':', '"', "'"],
    '?': ['.', '!', ',', ';', ':', '"', "'"], ',': ['.', '!', '?', ';', ':', '"', "'"],
    ';': ['.', '!', '?', ',', ':', '"', "'"], ':': ['.', '!', '?', ',', ';', '"', "'"],
    '"': ['.', '!', '?', ',', ';', ':', "'"], "'": ['.', '!', '?', ',', ';', ':', '"']
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _loadEntries();

    _contentController.addListener(_handleTextChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _contentController.removeListener(_handleTextChange);
    _contentController.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    final text = _contentController.text;
    if (text.length > _actualContent.length) {
      final char = text.substring(text.length - 1);
      final scrambledChar = _scrambleChar(char);
      _actualContent += char;
      final newText = text.substring(0, text.length - 1) + scrambledChar;
      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      );
    } else if (text.length < _actualContent.length) {
      _actualContent = _actualContent.substring(0, text.length);
    }
  }

  String _scrambleChar(String char) {
    final lowerChar = char.toLowerCase();
    if (keyboardRoulette.containsKey(lowerChar)) {
      final options = keyboardRoulette[lowerChar]!;
      final randomChar = options[Random().nextInt(options.length)];
      return char == lowerChar ? randomChar : randomChar.toUpperCase();
    }
    return char;
  }

  Future<void> _loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String? entriesString = prefs.getString('unconfessional-entries');
    if (entriesString != null) {
      final List<dynamic> entriesJson = jsonDecode(entriesString);
      setState(() {
        _entries = entriesJson.map((json) => Entry.fromJson(json)).toList();
      });
    }
    setState(() {
      _isLoaded = true;
    });
  }

  Future<void> _saveEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final String entriesString = jsonEncode(_entries.map((e) => e.toJson()).toList());
    await prefs.setString('unconfessional-entries', entriesString);
  }

  void _addEntry() {
    if (_titleController.text.trim().isEmpty && _actualContent.trim().isEmpty) {
      return;
    }
    final newEntry = Entry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      actualContent: _actualContent.trim(),
      createdAt: DateTime.now(),
    );
    setState(() {
      _entries.insert(0, newEntry);
      _titleController.clear();
      _contentController.clear();
      _actualContent = "";
    });
    _saveEntries();
  }


  void _toggleSpread() {
    setState(() {
      _isSpread = !_isSpread;
      if (_isSpread) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLargeScreen = size.width > 1024;
    final pageWidth = isLargeScreen ? 520.0 : size.width * 0.9;
    final pageHeight = pageWidth / (520 / 720);

    return Scaffold(
      backgroundColor: const Color(0xFF4a2511),
      body: Center(
        child: isLargeScreen
        ? _buildLargeScreenLayout(pageWidth, pageHeight)
        : _buildSmallScreenLayout(pageWidth, pageHeight),
      ),
    );
  }

  Widget _buildLargeScreenLayout(double pageWidth, double pageHeight) {
    return GestureDetector(
      onTap: _isSpread ? null : _toggleSpread,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spine
          if (_isSpread)
            Container(
              width: 2,
              height: pageHeight,
              color: Colors.black.withOpacity(0.7),
            ),
            // Left Page (Cover)
            Transform(
              alignment: Alignment.centerRight,
              transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(_animation.value * -0.5), // pi / 2 is 90 degrees
              child: _buildCoverPage(pageWidth, pageHeight, true),
            ),
            // Right Page (Content)
            if (_isSpread)
              Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(_animation.value * 0.5 - 0.5),
                child: _buildContentPage(pageWidth, pageHeight, true),
              ),
        ],
      ),
    );
  }

  Widget _buildSmallScreenLayout(double pageWidth, double pageHeight) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _isSpread
      ? _buildContentPage(pageWidth, pageHeight, false)
      : _buildCoverPage(pageWidth, pageHeight, false),
    );
  }

  Widget _buildCoverPage(double width, double height, bool isLargeScreen) {
    return Material(
      elevation: 10,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFd8c8a8),
          border: Border.all(color: const Color(0xFF2a150a), width: 2),
          borderRadius: isLargeScreen
          ? const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8))
          : BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            const OrnamentalBorder(),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
                    decoration: BoxDecoration(
                      border: Border.symmetric(horizontal: BorderSide(color: Colors.black.withOpacity(0.7), width: 2)),
                      color: const Color(0xFFd8c8a8).withOpacity(0.5),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'The Unconfessional',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Thoughts are safe here',
                          style: TextStyle(
                            color: Colors.black.withOpacity(0.8),
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    '❧',
                    style: TextStyle(
                      fontSize: 80,
                      color: Colors.black.withOpacity(0.15),
                    ),
                  ),
                ],
              ),
            ),
            if (!_isSpread)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _toggleSpread,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.25), Color.fromRGBO(0, 0, 0, 0.5)],
                        stops: [0.5, 0.51, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.only(bottomRight: Radius.circular(8), topLeft: Radius.circular(100)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentPage(double width, double height, bool isLargeScreen) {
    return Material(
      elevation: 10,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFf9e9ec),
          borderRadius: isLargeScreen
          ? const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8))
          : BorderRadius.circular(8),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Entry',
                    style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const Text("What's on your mind?", style: TextStyle(fontStyle: FontStyle.italic)),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      hintText: 'Give your thoughts a title',
                      border: InputBorder.none,
                    ),
                    style: GoogleFonts.playfairDisplay(fontSize: 18),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        hintText: 'Then write them down here...',
                        border: InputBorder.none,
                      ),
                      maxLines: null,
                      style: GoogleFonts.inconsolata(fontSize: 16, height: 1.5),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton(
                      onPressed: _addEntry,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFa3333d),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Seal Your Thoughts', style: TextStyle(color: Colors.white)),
                    ),
                  ),
                  const Divider(height: 40),
                  Text(
                    'Memories',
                    style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: _entries.isEmpty
                    ? const Text('Your scrambled thoughts will appear here once sealed.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                    : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(entry.title.isEmpty ? 'Untitled' : entry.title, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold)),
                            subtitle: Text(entry.content, maxLines: 2, overflow: TextOverflow.ellipsis, style: GoogleFonts.inconsolata()),
                            onTap: () {
                              // TODO: Implement viewing entry
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (_isSpread)
              Positioned(
                left: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _toggleSpread,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, Color.fromRGBO(0, 0, 0, 0.25), Color.fromRGBO(0, 0, 0, 0.5)],
                        stops: [0.5, 0.51, 1.0],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8), topRight: Radius.circular(100)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// --- Widgets ---
class OrnamentalBorder extends StatelessWidget {
  const OrnamentalBorder({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black.withOpacity(0.8), width: 4),
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.0),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black.withOpacity(0.7), width: 2),
                color: const Color(0xFFe87b95).withOpacity(0.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black.withOpacity(0.6), width: 1),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
