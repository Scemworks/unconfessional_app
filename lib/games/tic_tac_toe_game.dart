import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';

class TicTacToeGame extends StatefulWidget {
  final Function(bool) onGameEnd;
  const TicTacToeGame({super.key, required this.onGameEnd});

  @override
  State<TicTacToeGame> createState() => _TicTacToeGameState();
}

class _TicTacToeGameState extends State<TicTacToeGame> {
  late List<String?> _board;
  bool _playerTurn = true; // true = player X
  bool _gameOver = false;
  String? _winner;

  final List<List<int>> _winningCombos = [
    [0, 1, 2], [3, 4, 5], [6, 7, 8],
    [0, 3, 6], [1, 4, 7], [2, 5, 8],
    [0, 4, 8], [2, 4, 6],
  ];

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    setState(() {
      _board = List.filled(9, null);
      _playerTurn = true;
      _gameOver = false;
      _winner = null;
    });
  }

  void _handleClick(int index) {
    if (_board[index] != null || _gameOver || !_playerTurn) return;

    setState(() {
      _board[index] = 'X';
    _playerTurn = false;
    });

    if (_checkWinner()) return;

    Future.delayed(const Duration(milliseconds: 700), _aiMove);
  }

  void _aiMove() {
    if (_gameOver) return;

    int? bestMove;
    // Simple AI: find winning move or block player's winning move
    for (var combo in _winningCombos) {
      final line = combo.map((i) => _board[i]).toList();
      if (line.where((e) => e == 'O').length == 2 && line.contains(null)) {
        bestMove = combo[line.indexOf(null)];
        break;
      }
    }
    if (bestMove == null) {
      for (var combo in _winningCombos) {
        final line = combo.map((i) => _board[i]).toList();
        if (line.where((e) => e == 'X').length == 2 && line.contains(null)) {
          bestMove = combo[line.indexOf(null)];
          break;
        }
      }
    }

    // Otherwise, pick a random empty spot
    if (bestMove == null) {
      final emptySpots = [];
      for (int i = 0; i < _board.length; i++) {
        if (_board[i] == null) emptySpots.add(i);
      }
      if (emptySpots.isNotEmpty) {
        bestMove = emptySpots[Random().nextInt(emptySpots.length)];
      }
    }

    if (bestMove != null) {
      setState(() {
        _board[bestMove!] = 'O';
      _playerTurn = true;
      });
    }

    _checkWinner();
  }

  bool _checkWinner() {
    for (var combo in _winningCombos) {
      if (_board[combo[0]] != null &&
        _board[combo[0]] == _board[combo[1]] &&
        _board[combo[0]] == _board[combo[2]]) {
        _endGame(_board[combo[0]]);
      return true;
        }
    }
    if (!_board.contains(null)) {
      _endGame('draw');
      return true;
    }
    return false;
  }

  void _endGame(String? winner) {
    setState(() {
      _gameOver = true;
      _winner = winner;
    });
    widget.onGameEnd(winner == 'X');
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
          Text('The Ancient Grid', style: GoogleFonts.playfairDisplay(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Text(
            _gameOver
            ? (_winner == 'X' ? '🎉 Victory is yours!' : _winner == 'O' ? '💀 The Oracle prevails!' : '🤝 A draw! Honor shared!')
            : (_playerTurn ? "Your Turn (✗)" : "Oracle's Turn (◯)"),
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 9,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _handleClick(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: _board[index] == 'X' ? Colors.pink.shade300 : _board[index] == 'O' ? Colors.green.shade300 : Colors.brown,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _board[index] ?? '',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
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
                onPressed: _resetGame,
                child: const Text('Challenge the Oracle Again'),
              ),
            ),
        ],
      ),
    );
  }
}
