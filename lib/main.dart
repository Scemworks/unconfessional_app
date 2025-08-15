// lib/main.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:intl/intl.dart';

// --- Game Imports ---
import 'games/guess_num_game.dart';
import 'games/memory_game.dart';
import 'games/tic_tac_toe_game.dart';

// --- Models ---
class Entry {
  final String id;
  String title;
  String content;
  String actualContent;
  final DateTime createdAt;
  int failureCount;
  int? lockoutUntil;
  bool isDeciphered;

  Entry({
    required this.id,
    required this.title,
    required this.content,
    required this.actualContent,
    required this.createdAt,
    this.failureCount = 0,
    this.lockoutUntil,
    this.isDeciphered = false,
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
  bool _isGridView = true;

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
    // Timer to check for expired lockouts
    Timer.periodic(const Duration(seconds: 1), (timer) {
      _checkLockouts();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    _contentController.removeListener(_handleTextChange);
    _contentController.dispose();
    super.dispose();
  }

  void _checkLockouts() {
    final now = DateTime.now().millisecondsSinceEpoch;
    bool needsUpdate = false;
    for (var entry in _entries) {
      if (entry.lockoutUntil != null && now > entry.lockoutUntil!) {
        entry.lockoutUntil = null;
        entry.failureCount = 0;
        needsUpdate = true;
      }
    }
    if (needsUpdate) {
      setState(() {});
      _saveEntries();
    }
  }

  void _handleTextChange() {
    final text = _contentController.text;
    final selection = _contentController.selection;

    if (text.length > _actualContent.length) {
      final newChar = text.substring(selection.start - 1, selection.start);
      final scrambledChar = _scrambleChar(newChar);

      _actualContent = _actualContent.substring(0, selection.start - 1) + newChar + _actualContent.substring(selection.start - 1);
      final newText = text.substring(0, selection.start - 1) + scrambledChar + text.substring(selection.start);

      _contentController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start),
      );
    } else if (text.length < _actualContent.length) {
      final start = selection.start;
      _actualContent = _actualContent.substring(0, start) + _actualContent.substring(start + 1);
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

  void _showEntryDetail(Entry entry) {
    showDialog(
      context: context,
      builder: (context) => EntryDetailModal(
        entry: entry,
        onAttemptDecipher: () {
          _startDecipherAttempt(entry);
        },
      ),
    ).then((_) {
      // After the dialog is closed, check if the entry was deciphered and reset it
      if (entry.isDeciphered) {
        setState(() {
          entry.isDeciphered = false;
        });
      }
    });
  }

  void _startDecipherAttempt(Entry entry) {
    Navigator.of(context).pop(); // Close the detail modal
    final games = [
      GuessNumGame(onGameEnd: (won) => _handleGameEnd(entry, won)),
      MemoryGame(onGameEnd: (won) => _handleGameEnd(entry, won)),
      TicTacToeGame(onGameEnd: (won) => _handleGameEnd(entry, won)),
    ];
    final randomGame = games[Random().nextInt(games.length)];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        child: randomGame,
      ),
    );
  }

  void _handleGameEnd(Entry entry, bool won) {
    Navigator.of(context).pop(); // Close the game modal
    if (won) {
      setState(() {
        entry.isDeciphered = true;
        entry.failureCount = 0;
        entry.lockoutUntil = null;
      });
      _saveEntries();
      _showEntryDetail(entry); // Re-show the detail modal, now deciphered
    } else {
      setState(() {
        entry.failureCount++;
        if (entry.failureCount >= 3) {
          entry.lockoutUntil = DateTime.now().millisecondsSinceEpoch + 30000; // 30-second lockout
        }
      });
      _saveEntries();
      _showEntryDetail(entry); // Re-show the detail modal with updated failure count
    }
  }

  void _clearAllMemories() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Burn Your Memories?'),
        content: const Text('This will permanently destroy all of your sealed thoughts. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Have Mercy'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _entries.clear();
              });
              _saveEntries();
              Navigator.of(context).pop();
            },
            child: const Text('Burn Them All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
              ..rotateY(_animation.value * -pi / 2.2),
              child: _buildCoverPage(pageWidth, pageHeight, true),
            ),
            // Right Page (Content)
            if (_isSpread)
              Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(-pi / 2.2 + _animation.value * pi / 2.2),
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
        key: const ValueKey('cover'),
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
        key: const ValueKey('content'),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Memories',
                        style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.grid_view, color: _isGridView ? Colors.pink.shade300 : Colors.grey),
                            onPressed: () => setState(() => _isGridView = true),
                          ),
                          IconButton(
                            icon: Icon(Icons.view_list, color: !_isGridView ? Colors.pink.shade300 : Colors.grey),
                            onPressed: () => setState(() => _isGridView = false),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_forever, color: Colors.red),
                            onPressed: _clearAllMemories,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Expanded(
                    child: _entries.isEmpty
                    ? const Text('Your scrambled thoughts will appear here once sealed.', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))
                    : _isGridView
                    ? GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 3 / 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return Card(
                          elevation: 1,
                          child: InkWell(
                            onTap: () => _showEntryDetail(entry),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(entry.title.isEmpty ? 'Untitled' : entry.title, style: GoogleFonts.playfairDisplay(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  const SizedBox(height: 4),
                                  Expanded(child: Text(entry.content, style: GoogleFonts.inconsolata(), overflow: TextOverflow.ellipsis, maxLines: 2)),
                                  if ((entry.lockoutUntil ?? 0) > DateTime.now().millisecondsSinceEpoch)
                                    const Align(alignment: Alignment.bottomRight, child: Icon(Icons.lock, color: Colors.red, size: 16)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    )
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
                            trailing: (entry.lockoutUntil ?? 0) > DateTime.now().millisecondsSinceEpoch ? const Icon(Icons.lock, color: Colors.red) : null,
                            onTap: () => _showEntryDetail(entry),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            if (isLargeScreen || _isSpread)
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

class EntryDetailModal extends StatefulWidget {
  final Entry entry;
  final VoidCallback onAttemptDecipher;
  const EntryDetailModal({super.key, required this.entry, required this.onAttemptDecipher});

  @override
  State<EntryDetailModal> createState() => _EntryDetailModalState();
}

class _EntryDetailModalState extends State<EntryDetailModal> {
  Timer? _timer;
  late Duration _remainingTime;
  bool _isShowingDeciphered = false;

  @override
  void initState() {
    super.initState();
    _isShowingDeciphered = widget.entry.isDeciphered;
    if (_isShowingDeciphered) {
      // Start a timer to re-scramble the text after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isShowingDeciphered = false;
            widget.entry.isDeciphered = false;
          });
        }
      });
    }
    _updateRemainingTime();
    if (_isLocked()) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        _updateRemainingTime();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemainingTime() {
    if (!_isLocked()) {
      _timer?.cancel();
      if (mounted) setState(() {});
      return;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final remainingMillis = widget.entry.lockoutUntil! - now;
    setState(() {
      _remainingTime = Duration(milliseconds: remainingMillis > 0 ? remainingMillis : 0);
    });
  }

  bool _isLocked() {
    return widget.entry.lockoutUntil != null && widget.entry.lockoutUntil! > DateTime.now().millisecondsSinceEpoch;
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      backgroundColor: const Color(0xFFfdf6f7),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.entry.title.isEmpty ? 'Untitled' : widget.entry.title,
              style: GoogleFonts.playfairDisplay(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Created on: ${DateFormat.yMMMd().add_jm().format(widget.entry.createdAt)}',
              style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _isShowingDeciphered ? widget.entry.actualContent : widget.entry.content,
                  style: GoogleFonts.inconsolata(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: _isLocked()
              ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Text(
                  '🔒 Locked for: ${_formatDuration(_remainingTime)}',
                  style: GoogleFonts.inconsolata(color: Colors.red.shade800, fontWeight: FontWeight.bold),
                ),
              )
              : ElevatedButton.icon(
                onPressed: widget.onAttemptDecipher,
                icon: const Icon(Icons.lock_open),
                label: Text('Attempt to Decipher (${widget.entry.failureCount}/3)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade200,
                  foregroundColor: Colors.blue.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
