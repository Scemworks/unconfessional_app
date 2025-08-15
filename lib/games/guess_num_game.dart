import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';

class GuessNumGame extends StatefulWidget {
  final Function(bool) onGameEnd;
  const GuessNumGame({super.key, required this.onGameEnd});

  @override
  State<GuessNumGame> createState() => _GuessNumGameState();
}

class _GuessNumGameState extends State<GuessNumGame> {
  final int _range = 100;
  final int _maxAttempts = 5;
  late int _target;
  final TextEditingController _guessController = TextEditingController();
  int _attemptsLeft = 0;
  String _feedback = "";
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      _target = Random().nextInt(_range) + 1;
      _attemptsLeft = _maxAttempts;
      _feedback = "Guess the number between 1 and $_range!";
      _gameOver = false;
      _guessController.clear();
    });
  }

  void _handleGuess() {
    if (_gameOver) return;
    final int? guess = int.tryParse(_guessController.text);

    if (guess == null) {
      setState(() {
        _feedback = "Please enter a valid number.";
      });
      return;
    }

    if (guess == _target) {
      setState(() {
        _feedback = "👑 You got it! The number was $_target!";
        _gameOver = true;
      });
      widget.onGameEnd(true);
    } else {
      setState(() {
        _attemptsLeft--;
        if (_attemptsLeft == 0) {
          _feedback = "💔 Game Over. The number was $_target.";
          _gameOver = true;
          widget.onGameEnd(false);
        } else {
          _feedback = guess < _target ? "⬆️ Guess higher" : "⬇️ Guess lower";
        }
      });
    }
    _guessController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
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
          Text('The Number Oracle', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Text(_feedback, style: const TextStyle(color: Colors.white, fontSize: 18)),
          const SizedBox(height: 16),
          if (!_gameOver) ...[
            TextField(
              controller: _guessController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Your sacred guess...',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _handleGuess(),
            ),
            const SizedBox(height: 8),
            Text('Attempts Left: $_attemptsLeft', style: const TextStyle(color: Colors.white)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _handleGuess,
              child: const Text('Consult the Oracle'),
            ),
          ] else
          ElevatedButton(
            onPressed: _resetGame,
            child: const Text('Seek Another Prophecy'),
          ),
        ],
      ),
    );
  }
}
