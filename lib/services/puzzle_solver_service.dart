import 'dart:collection';
import 'package:get/get.dart';
import '../controllers/ball_sort_controller.dart';

class Move {
  final int from;
  final int to;
  Move(this.from, this.to);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Move &&
          runtimeType == other.runtimeType &&
          from == other.from &&
          to == other.to;

  @override
  int get hashCode => from.hashCode ^ to.hashCode;
}

class PuzzleState {
  final List<List<String>> tubes;
  PuzzleState(this.tubes);

  bool isSolved() {
    return tubes.every((t) =>
        t.isEmpty ||
        (t.length == BallSortController.kTubeCapacity &&
            t.toSet().length == 1));
  }

  String get id => tubes.map((t) => t.join(',')).join('|');
}

class PuzzleSolverService extends GetxService {
  int minimumMovesToSolve(List<Tube> initialTubes) {
    final solution = computeBestSolution(initialTubes);
    if (solution == null) return -1;
    return solution.length;
  }

  List<Move>? computeBestSolution(List<Tube> initialTubes) {
    // BFS to find shortest path
    final startState = PuzzleState(
        initialTubes.map((t) => List<String>.from(t.balls)).toList());

    if (startState.isSolved()) return [];

    Queue<Map<String, dynamic>> queue = Queue();
    queue.add({'state': startState, 'moves': <Move>[]});

    Set<String> visited = {startState.id};

    int iterations = 0;
    const maxIterations = 5000; // Prevent infinite loop / freezing

    while (queue.isNotEmpty && iterations < maxIterations) {
      iterations++;
      final current = queue.removeFirst();
      final PuzzleState state = current['state'];
      final List<Move> path = current['moves'];

      for (int i = 0; i < state.tubes.length; i++) {
        if (state.tubes[i].isEmpty) continue;

        for (int j = 0; j < state.tubes.length; j++) {
          if (i == j) continue;
          if (state.tubes[j].length >= BallSortController.kTubeCapacity)
            continue;

          if (state.tubes[j].isEmpty ||
              state.tubes[j].last == state.tubes[i].last) {
            // Valid move
            List<List<String>> nextStateTubes =
                state.tubes.map((t) => List<String>.from(t)).toList();
            nextStateTubes[j].add(nextStateTubes[i].removeLast());

            final nextState = PuzzleState(nextStateTubes);
            final nextStateId = nextState.id;

            if (!visited.contains(nextStateId)) {
              final newPath = List<Move>.from(path)..add(Move(i, j));
              if (nextState.isSolved()) {
                return newPath;
              }
              visited.add(nextStateId);
              queue.add({'state': nextState, 'moves': newPath});
            }
          }
        }
      }
    }

    return null; // Unsolvable or too complex
  }
}
