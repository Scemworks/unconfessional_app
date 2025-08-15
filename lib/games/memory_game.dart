import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';

class MemoryGame extends StatefulWidget {
  final Function(bool) onGameEnd;
  const MemoryGame({super.key, required this.onGameEnd});

  @override
  State<MemoryGame> createState() => _MemoryGameState();
}

class _MemoryGameState extends State<MemoryGame> {
  final List<String> _symbols = ["🍕", "🦄", "💩", "🤡", "👹", "🦖", "👽", "🐙"];
  late List<String> _cards;
  List<int> _flipped = [];
  List<int> _matched = [];
  Timer? _timer;
  int _timeLeft = 60;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    setState(() {
      _cards = [..._symbols, ..._symbols]..shuffle();
      _flipped.clear();
      _matched.clear();
      _timeLeft = 60;
      _gameOver = false;
      _startTimer();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        _timer?.cancel();
        if (!_gameOver) {
          setState(() {
            _gameOver = true;
          });
          widget.onGameEnd(false);
        }
      }
    });
  }

  void _handleFlip(int index) {
    if (_gameOver || _flipped.length == 2 || _flipped.contains(index) || _matched.contains(index)) {
      return;
    }

    setState(() {
      _flipped.add(index);
    });

    if (_flipped.length == 2) {
      Future.delayed(const Duration(milliseconds: 700), () {
        final first = _flipped[0];
        final second = _flipped[1];
        if (_cards[first] == _cards[second]) {
          setState(() {
            _matched.addAll([first, second]);
            if (_matched.length == _cards.length) {
              _gameOver = true;
              _timer?.cancel();
              widget.onGameEnd(true);
            }
          });
        }
        setState(() {
          _flipped.clear();
        });
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFFDEB887), Color(0xFF654321)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('The Memory Sanctum', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Text('Time Remaining: $_timeLeft', style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _cards.length,
            itemBuilder: (context, index) {
              final isFlipped = _flipped.contains(index) || _matched.contains(index);
              return GestureDetector(
                onTap: () => _handleFlip(index),
                child: Card(
                  color: isFlipped ? Colors.pink.shade300 : Colors.brown,
                  child: Center(
                    child: Text(
                      isFlipped ? _cards[index] : '📜',
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
              );
            },
          ),
          if (_gameOver)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: ElevatedButton(
                onPressed: _startGame,
                child: const Text('Journey Into Memory Again'),
              ),
            ),
        ],
      ),
    );
  }
}
