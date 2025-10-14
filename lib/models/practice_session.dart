import 'package:uuid/uuid.dart';

/// Represents a single practice session where a user practices kubb throwing
/// Tracks progress, rounds, and provides statistics
class PracticeSession {
  // Core Properties
  final String id;
  final DateTime date;
  int target;
  int totalKubbs;
  int totalBatons;
  DateTime startTime;
  DateTime? endTime;
  bool isComplete;
  bool isPaused;
  List<Round> rounds;
  final DateTime createdAt;
  DateTime modifiedAt;

  PracticeSession({
    String? id,
    DateTime? date,
    required this.target,
    DateTime? startTime,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        totalKubbs = 0,
        totalBatons = 0,
        startTime = startTime ?? DateTime.now(),
        endTime = null,
        isComplete = false,
        isPaused = false,
        rounds = [],
        createdAt = DateTime.now(),
        modifiedAt = DateTime.now() {
    // Create the first round immediately when starting a new session
    rounds.add(Round(roundNumber: 1));
  }

  // Full constructor for deserialization
  PracticeSession._({
    required this.id,
    required this.date,
    required this.target,
    required this.totalKubbs,
    required this.totalBatons,
    required this.startTime,
    this.endTime,
    required this.isComplete,
    required this.isPaused,
    required this.rounds,
    required this.createdAt,
    required this.modifiedAt,
  });

  // Computed Properties

  double get accuracy {
    if (totalBatons == 0) return 0.0;
    return totalKubbs / totalBatons;
  }

  double get progressPercentage {
    if (target == 0) return 0.0;
    return (totalBatons / target).clamp(0.0, 1.0);
  }

  bool get isTargetReached => totalBatons >= target;

  bool get isIncomplete {
    // A session is incomplete ONLY if it's from today and either paused or hasn't reached the target
    final isToday = _isDateToday(date);
    return isToday && (isPaused || !isTargetReached);
  }

  Round? get currentRound {
    try {
      return rounds.firstWhere((round) => !round.isComplete);
    } catch (e) {
      return null;
    }
  }

  List<Round> get completedRounds {
    return rounds.where((round) => round.isComplete).toList();
  }

  int get totalBaselineClears {
    return rounds.where((round) => round.hasBaselineClear).length;
  }

  int get totalKingThrows {
    return rounds.fold(0, (sum, round) => sum + round.kingThrowsCount);
  }

  int get totalKingHits {
    return rounds.fold(0, (sum, round) => sum + round.kingHits);
  }

  int get totalKingThrowAttempts {
    return rounds.fold(0, (sum, round) => sum + round.kingThrowAttempts);
  }

  double get kingAccuracy {
    if (totalKingThrowAttempts == 0) return 0.0;
    return totalKingHits / totalKingThrowAttempts;
  }

  // Session Management Methods

  void addBatonResult(bool isHit) {
    // Don't add batons if the current round is complete
    final current = currentRound;
    if (current == null || current.isRoundComplete) return;

    totalBatons++;
    if (isHit) {
      totalKubbs++;
    }
    modifiedAt = DateTime.now();

    // Update current round
    final index = rounds.indexWhere((r) => r.id == current.id);
    if (index != -1) {
      // Determine throw type based on current round state
      final throwType = (current.hits >= 5 && current.totalBatonThrows == 5)
          ? ThrowType.king
          : ThrowType.kubb;

      rounds[index].addBatonThrow(isHit: isHit, throwType: throwType);
    }
  }

  void startNextRound() {
    rounds.add(Round(roundNumber: rounds.length + 1));
    modifiedAt = DateTime.now();
  }

  void completeSession() {
    isComplete = true;
    isPaused = false;
    endTime = DateTime.now();
    modifiedAt = DateTime.now();
  }

  void pauseSession() {
    isPaused = true;
    modifiedAt = DateTime.now();
  }

  void resumeSession() {
    isPaused = false;
    modifiedAt = DateTime.now();
  }

  void endSessionEarly() {
    endTime = DateTime.now();
    modifiedAt = DateTime.now();
  }

  void resetCurrentRound() {
    final current = currentRound;
    if (current == null) return;

    final index = rounds.indexWhere((r) => r.id == current.id);
    if (index != -1) {
      rounds[index] = Round(roundNumber: current.roundNumber);
    }
  }

  PracticeSession withAutoCompletion() {
    final isToday = _isDateToday(date);

    // If it's not from today and not already complete, mark it as complete
    if (!isToday && !isComplete) {
      return PracticeSession._(
        id: id,
        date: date,
        target: target,
        totalKubbs: totalKubbs,
        totalBatons: totalBatons,
        startTime: startTime,
        endTime: endTime ?? DateTime.now(),
        isComplete: true,
        isPaused: false,
        rounds: rounds,
        createdAt: createdAt,
        modifiedAt: modifiedAt, // Don't update modifiedAt to prevent sync loops
      );
    }

    return this;
  }

  // Helper Methods

  bool _isDateToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'target': target,
      'totalKubbs': totalKubbs,
      'totalBatons': totalBatons,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isComplete': isComplete,
      'isPaused': isPaused,
      'rounds': rounds.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  factory PracticeSession.fromJson(Map<String, dynamic> json) {
    return PracticeSession._(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      target: json['target'] as int,
      totalKubbs: json['totalKubbs'] as int,
      totalBatons: json['totalBatons'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      isComplete: json['isComplete'] as bool,
      isPaused: json['isPaused'] as bool,
      rounds: (json['rounds'] as List)
          .map((r) => Round.fromJson(r as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    );
  }
}

/// Represents a single round within a practice session
class Round {
  final String id;
  final int roundNumber;
  List<BatonThrow> batonThrows;
  final DateTime createdAt;
  bool isComplete;

  Round({
    String? id,
    required this.roundNumber,
  })  : id = id ?? const Uuid().v4(),
        batonThrows = [],
        createdAt = DateTime.now(),
        isComplete = false;

  Round._({
    required this.id,
    required this.roundNumber,
    required this.batonThrows,
    required this.createdAt,
    required this.isComplete,
  });

  // Computed Properties

  int get totalBatonThrows => batonThrows.length;

  int get hits => batonThrows.where((t) => t.isHit).length;

  int get misses => batonThrows.where((t) => !t.isHit).length;

  double get accuracy {
    if (totalBatonThrows == 0) return 0.0;
    return hits / totalBatonThrows;
  }

  bool get hasBaselineClear => hits >= 5;

  int get kingThrowsCount =>
      batonThrows.where((t) => t.throwType == ThrowType.king).length;

  int get kingHits => batonThrows
      .where((t) => t.throwType == ThrowType.king && t.isHit)
      .length;

  int get kingThrowAttempts =>
      batonThrows.where((t) => t.throwType == ThrowType.king).length;

  bool get isRoundComplete {
    // Round is complete if we have 5 hits (baseline clear)
    // Or if we have 6 throws total (5 kubb attempts + 1 king attempt)
    if (hits >= 5 && totalBatonThrows >= 6) return true;
    if (totalBatonThrows >= 6) return true;
    return false;
  }

  // Round Management

  void addBatonThrow({required bool isHit, required ThrowType throwType}) {
    batonThrows.add(BatonThrow(
      isHit: isHit,
      throwType: throwType,
      throwNumber: batonThrows.length + 1,
    ));
  }

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roundNumber': roundNumber,
      'batonThrows': batonThrows.map((t) => t.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'isComplete': isComplete,
    };
  }

  factory Round.fromJson(Map<String, dynamic> json) {
    return Round._(
      id: json['id'] as String,
      roundNumber: json['roundNumber'] as int,
      batonThrows: (json['batonThrows'] as List)
          .map((t) => BatonThrow.fromJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      isComplete: json['isComplete'] as bool,
    );
  }
}

/// Represents a single baton throw
class BatonThrow {
  final String id;
  final bool isHit;
  final ThrowType throwType;
  final int throwNumber;
  final DateTime timestamp;

  BatonThrow({
    String? id,
    required this.isHit,
    required this.throwType,
    required this.throwNumber,
  })  : id = id ?? const Uuid().v4(),
        timestamp = DateTime.now();

  BatonThrow._({
    required this.id,
    required this.isHit,
    required this.throwType,
    required this.throwNumber,
    required this.timestamp,
  });

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isHit': isHit,
      'throwType': throwType.toString().split('.').last,
      'throwNumber': throwNumber,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory BatonThrow.fromJson(Map<String, dynamic> json) {
    return BatonThrow._(
      id: json['id'] as String,
      isHit: json['isHit'] as bool,
      throwType: ThrowType.values.firstWhere(
        (e) => e.toString().split('.').last == json['throwType'],
      ),
      throwNumber: json['throwNumber'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Type of throw
enum ThrowType {
  kubb,
  king,
}

