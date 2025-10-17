import 'package:uuid/uuid.dart';
import 'dart:math';

/// Game phase for Inkast Blast training
enum GamePhase {
  early('Early Game', 1, 3),
  mid('Mid Game', 4, 7),
  end('End Game', 8, 10),
  all('All Phases', 1, 10);

  final String displayName;
  final int minKubbs;
  final int maxKubbs;

  const GamePhase(this.displayName, this.minKubbs, this.maxKubbs);

  String get description {
    switch (this) {
      case GamePhase.early:
        return 'Practice with 1-3 kubbs';
      case GamePhase.mid:
        return 'Practice with 4-7 kubbs';
      case GamePhase.end:
        return 'Practice with 8-10 kubbs';
      case GamePhase.all:
        return 'Practice with 1-10 kubbs (random)';
    }
  }

  /// Generate a random number of kubbs within this phase's range
  int generateRandomKubbCount() {
    final random = Random();
    return minKubbs + random.nextInt(maxKubbs - minKubbs + 1);
  }
}

/// Represents an Inkast Blast training session
class InkastBlastSession {
  final String id;
  final DateTime date;
  final GamePhase gamePhase;
  DateTime startTime;
  DateTime? endTime;
  bool isComplete;
  bool isPaused;
  int totalRounds;
  int totalInkastKubbs;
  int totalKubbsClearedFirstThrow;
  int totalBatonsUsed;
  int totalPenaltyKubbs;
  int totalNeighborKubbs;
  int totalMisses;
  List<InkastBlastRound> rounds;
  final DateTime createdAt;
  DateTime modifiedAt;

  InkastBlastSession({
    String? id,
    DateTime? date,
    required this.gamePhase,
    DateTime? startTime,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        startTime = startTime ?? DateTime.now(),
        endTime = null,
        isComplete = false,
        isPaused = false,
        totalRounds = 0,
        totalInkastKubbs = 0,
        totalKubbsClearedFirstThrow = 0,
        totalBatonsUsed = 0,
        totalPenaltyKubbs = 0,
        totalNeighborKubbs = 0,
        totalMisses = 0,
        rounds = [],
        createdAt = DateTime.now(),
        modifiedAt = DateTime.now();

  InkastBlastSession._({
    required this.id,
    required this.date,
    required this.gamePhase,
    required this.startTime,
    this.endTime,
    required this.isComplete,
    required this.isPaused,
    required this.totalRounds,
    required this.totalInkastKubbs,
    required this.totalKubbsClearedFirstThrow,
    required this.totalBatonsUsed,
    required this.totalPenaltyKubbs,
    required this.totalNeighborKubbs,
    required this.totalMisses,
    required this.rounds,
    required this.createdAt,
    required this.modifiedAt,
  });

  // Computed Properties

  InkastBlastRound? get currentRound {
    try {
      return rounds.firstWhere((round) => !round.isComplete);
    } catch (e) {
      return null;
    }
  }

  List<InkastBlastRound> get completedRounds {
    return rounds.where((round) => round.isComplete).toList();
  }

  int get totalKubbsKnockedDown {
    return rounds.fold(0, (sum, round) => sum + round.totalKubbsKnockedDown);
  }

  double get averageKubbsPerBaton {
    if (totalBatonsUsed == 0) return 0.0;
    return totalKubbsKnockedDown / totalBatonsUsed;
  }

  double get averageKubbsPerRound {
    if (totalRounds == 0) return 0.0;
    return totalInkastKubbs / totalRounds;
  }

  double get averageBatonsPerRound {
    if (totalRounds == 0) return 0.0;
    return totalBatonsUsed / totalRounds;
  }

  double get penaltyRate {
    if (totalInkastKubbs == 0) return 0.0;
    return totalPenaltyKubbs / totalInkastKubbs;
  }

  double get neighborRate {
    if (totalInkastKubbs == 0) return 0.0;
    return totalNeighborKubbs / totalInkastKubbs;
  }

  int get kubbsOutOfBounds {
    return rounds.fold(
      0,
      (sum, round) =>
          sum + round.kubbsOutFirstAttempt + round.kubbsOutSecondAttempt,
    );
  }

  // Session Management

  void addRound(InkastBlastRound round) {
    rounds.add(round);
    totalRounds++;
    totalInkastKubbs += round.inkastKubbs;
    totalKubbsClearedFirstThrow += round.kubbsClearedFirstThrow;
    totalBatonsUsed += round.batonsUsed;
    totalPenaltyKubbs += round.penaltyKubbs;
    totalNeighborKubbs += round.neighborKubbs;
    totalMisses += round.misses;
    modifiedAt = DateTime.now();
  }

  void completeSession() {
    isComplete = true;
    endTime = DateTime.now();
    modifiedAt = DateTime.now();
  }

  void pauseSession() {
    isPaused = true;
    endTime = DateTime.now();
    modifiedAt = DateTime.now();
  }

  void resumeSession() {
    isPaused = false;
    endTime = null;
    modifiedAt = DateTime.now();
  }

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'gamePhase': gamePhase.name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isComplete': isComplete,
      'isPaused': isPaused,
      'totalRounds': totalRounds,
      'totalInkastKubbs': totalInkastKubbs,
      'totalKubbsClearedFirstThrow': totalKubbsClearedFirstThrow,
      'totalBatonsUsed': totalBatonsUsed,
      'totalPenaltyKubbs': totalPenaltyKubbs,
      'totalNeighborKubbs': totalNeighborKubbs,
      'totalMisses': totalMisses,
      'rounds': rounds.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  factory InkastBlastSession.fromJson(Map<String, dynamic> json) {
    return InkastBlastSession._(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      gamePhase: GamePhase.values.firstWhere(
        (e) => e.name == json['gamePhase'],
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      isComplete: json['isComplete'] as bool,
      isPaused: json['isPaused'] as bool,
      totalRounds: json['totalRounds'] as int,
      totalInkastKubbs: json['totalInkastKubbs'] as int,
      totalKubbsClearedFirstThrow: json['totalKubbsClearedFirstThrow'] as int,
      totalBatonsUsed: json['totalBatonsUsed'] as int,
      totalPenaltyKubbs: json['totalPenaltyKubbs'] as int,
      totalNeighborKubbs: json['totalNeighborKubbs'] as int,
      totalMisses: json['totalMisses'] as int,
      rounds: (json['rounds'] as List)
          .map((r) => InkastBlastRound.fromJson(r as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    );
  }
}

/// Represents a single round in an Inkast Blast session
class InkastBlastRound {
  final String id;
  final int roundNumber;
  int inkastKubbs;
  int kubbsOutFirstAttempt;
  int kubbsOutSecondAttempt;
  int penaltyKubbs;
  int neighborKubbs;
  int kubbsClearedFirstThrow;
  int batonsUsed;
  int misses;
  bool isComplete;
  List<InkastBatonThrow> batonThrows;
  final DateTime createdAt;

  InkastBlastRound({
    String? id,
    required this.roundNumber,
    required this.inkastKubbs,
  })  : id = id ?? const Uuid().v4(),
        kubbsOutFirstAttempt = 0,
        kubbsOutSecondAttempt = 0,
        penaltyKubbs = 0,
        neighborKubbs = 0,
        kubbsClearedFirstThrow = 0,
        batonsUsed = 0,
        misses = 0,
        isComplete = false,
        batonThrows = [],
        createdAt = DateTime.now();

  InkastBlastRound._({
    required this.id,
    required this.roundNumber,
    required this.inkastKubbs,
    required this.kubbsOutFirstAttempt,
    required this.kubbsOutSecondAttempt,
    required this.penaltyKubbs,
    required this.neighborKubbs,
    required this.kubbsClearedFirstThrow,
    required this.batonsUsed,
    required this.misses,
    required this.isComplete,
    required this.batonThrows,
    required this.createdAt,
  });

  // Computed Properties

  int get totalKubbsInBounds => inkastKubbs - penaltyKubbs;

  int get kubbsRemaining => totalKubbsInBounds - kubbsClearedFirstThrow;

  int get totalKubbsKnockedDown {
    return batonThrows.fold(
      0,
      (sum, batonThrow) => sum + (batonThrow.isHit ? batonThrow.kubbsHit : 0),
    );
  }

  double get averageKubbsPerBaton {
    if (batonsUsed == 0) return 0.0;
    return totalKubbsKnockedDown / batonsUsed;
  }

  int get targetBatons {
    switch (inkastKubbs) {
      case 1:
      case 2:
        return 1;
      case 3:
      case 4:
        return 2;
      case 5:
      case 6:
      case 7:
        return 3;
      case 8:
      case 9:
      case 10:
        return 4;
      default:
        return ((inkastKubbs + 1) / 2).ceil();
    }
  }

  int get performanceVsTarget => targetBatons - batonsUsed;

  bool get isUnderTarget => batonsUsed < targetBatons;

  bool get isOverTarget => batonsUsed > targetBatons;

  int get kubbsOutOfBounds => kubbsOutFirstAttempt + kubbsOutSecondAttempt;

  // Round Management

  void recordInkastResults({
    required int firstAttemptOut,
    required int secondAttemptOut,
    required int neighbors,
  }) {
    kubbsOutFirstAttempt = firstAttemptOut;
    kubbsOutSecondAttempt = secondAttemptOut;
    penaltyKubbs = secondAttemptOut;
    neighborKubbs = neighbors;
  }

  void addBatonThrow({required bool isHit, int kubbsHit = 0}) {
    final batonThrow = InkastBatonThrow(
      isHit: isHit,
      kubbsHit: kubbsHit,
      throwNumber: batonThrows.length + 1,
    );
    batonThrows.add(batonThrow);

    batonsUsed++;

    if (isHit) {
      kubbsClearedFirstThrow += kubbsHit;
    } else {
      misses++;
    }

    // Check if round is complete (all kubbs cleared, including penalty kubbs)
    final totalKubbsToClear = totalKubbsInBounds + penaltyKubbs;
    if (kubbsClearedFirstThrow >= totalKubbsToClear) {
      isComplete = true;
    }
  }

  void completeRound() {
    isComplete = true;
  }

  void resetRound() {
    kubbsOutFirstAttempt = 0;
    kubbsOutSecondAttempt = 0;
    penaltyKubbs = 0;
    neighborKubbs = 0;
    kubbsClearedFirstThrow = 0;
    batonsUsed = 0;
    misses = 0;
    isComplete = false;
    batonThrows = [];
  }

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roundNumber': roundNumber,
      'inkastKubbs': inkastKubbs,
      'kubbsOutFirstAttempt': kubbsOutFirstAttempt,
      'kubbsOutSecondAttempt': kubbsOutSecondAttempt,
      'penaltyKubbs': penaltyKubbs,
      'neighborKubbs': neighborKubbs,
      'kubbsClearedFirstThrow': kubbsClearedFirstThrow,
      'batonsUsed': batonsUsed,
      'misses': misses,
      'isComplete': isComplete,
      'batonThrows': batonThrows.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory InkastBlastRound.fromJson(Map<String, dynamic> json) {
    return InkastBlastRound._(
      id: json['id'] as String,
      roundNumber: json['roundNumber'] as int,
      inkastKubbs: json['inkastKubbs'] as int,
      kubbsOutFirstAttempt: json['kubbsOutFirstAttempt'] as int,
      kubbsOutSecondAttempt: json['kubbsOutSecondAttempt'] as int,
      penaltyKubbs: json['penaltyKubbs'] as int,
      neighborKubbs: json['neighborKubbs'] as int,
      kubbsClearedFirstThrow: json['kubbsClearedFirstThrow'] as int,
      batonsUsed: json['batonsUsed'] as int,
      misses: json['misses'] as int,
      isComplete: json['isComplete'] as bool,
      batonThrows: (json['batonThrows'] as List)
          .map((t) => InkastBatonThrow.fromJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Represents a single baton throw in an Inkast Blast round
class InkastBatonThrow {
  final String id;
  final bool isHit;
  final int kubbsHit;
  final int throwNumber;
  final DateTime timestamp;

  InkastBatonThrow({
    String? id,
    required this.isHit,
    required this.kubbsHit,
    required this.throwNumber,
  })  : id = id ?? const Uuid().v4(),
        timestamp = DateTime.now();

  InkastBatonThrow._({
    required this.id,
    required this.isHit,
    required this.kubbsHit,
    required this.throwNumber,
    required this.timestamp,
  });

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isHit': isHit,
      'kubbsHit': kubbsHit,
      'throwNumber': throwNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory InkastBatonThrow.fromJson(Map<String, dynamic> json) {
    return InkastBatonThrow._(
      id: json['id'] as String,
      isHit: json['isHit'] as bool,
      kubbsHit: json['kubbsHit'] as int,
      throwNumber: json['throwNumber'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

