import 'package:uuid/uuid.dart';

/// Game phase for Full Game Simulation
enum FullGamePhase {
  attacking('Attacking'),
  inkast('Inkast'),
  roundComplete('Round Complete');

  final String displayName;
  const FullGamePhase(this.displayName);
}

/// Represents a Full Game Simulation training session
class FullGameSimSession {
  final String id;
  final DateTime date;
  DateTime startTime;
  DateTime? endTime;
  bool isComplete;
  bool isPaused;
  int currentRound;
  FullGamePhase currentPhase;
  int totalRounds;
  int totalInkastKubbs;
  int totalKubbsClearedFirstThrow;
  int totalBatonsUsed;
  int totalPenaltyKubbs;
  int totalNeighborKubbs;
  int totalMisses;
  int totalEightMeterHits;
  int totalEightMeterBatons;
  int team1BaselineKubbs;
  int team2BaselineKubbs;
  int team1UnclearedKubbs;
  int team2UnclearedKubbs;
  bool kingHit;
  List<FullGameSimRound> rounds;
  final DateTime createdAt;
  DateTime modifiedAt;

  FullGameSimSession({
    String? id,
    DateTime? date,
    DateTime? startTime,
  })  : id = id ?? const Uuid().v4(),
        date = date ?? DateTime.now(),
        startTime = startTime ?? DateTime.now(),
        endTime = null,
        isComplete = false,
        isPaused = false,
        currentRound = 1,
        currentPhase = FullGamePhase.attacking,
        totalRounds = 0,
        totalInkastKubbs = 0,
        totalKubbsClearedFirstThrow = 0,
        totalBatonsUsed = 0,
        totalPenaltyKubbs = 0,
        totalNeighborKubbs = 0,
        totalMisses = 0,
        totalEightMeterHits = 0,
        totalEightMeterBatons = 0,
        team1BaselineKubbs = 5,
        team2BaselineKubbs = 5,
        team1UnclearedKubbs = 0,
        team2UnclearedKubbs = 0,
        kingHit = false,
        rounds = [],
        createdAt = DateTime.now(),
        modifiedAt = DateTime.now();

  FullGameSimSession._({
    required this.id,
    required this.date,
    required this.startTime,
    this.endTime,
    required this.isComplete,
    required this.isPaused,
    required this.currentRound,
    required this.currentPhase,
    required this.totalRounds,
    required this.totalInkastKubbs,
    required this.totalKubbsClearedFirstThrow,
    required this.totalBatonsUsed,
    required this.totalPenaltyKubbs,
    required this.totalNeighborKubbs,
    required this.totalMisses,
    required this.totalEightMeterHits,
    required this.totalEightMeterBatons,
    required this.team1BaselineKubbs,
    required this.team2BaselineKubbs,
    required this.team1UnclearedKubbs,
    required this.team2UnclearedKubbs,
    required this.kingHit,
    required this.rounds,
    required this.createdAt,
    required this.modifiedAt,
  });

  // Computed Properties

  FullGameSimRound? get currentRoundData {
    try {
      return rounds.firstWhere((r) => r.roundNumber == currentRound);
    } catch (e) {
      return null;
    }
  }

  int get currentAttackingTeam => currentRound % 2 == 1 ? 1 : 2;

  int get currentBaselineKubbs =>
      currentAttackingTeam == 1 ? team1BaselineKubbs : team2BaselineKubbs;

  List<FullGameSimRound> get completedRounds {
    return rounds.where((r) => r.isComplete).toList();
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

  double get eightMeterAccuracy {
    if (totalEightMeterBatons == 0) return 0.0;
    return totalEightMeterHits / totalEightMeterBatons;
  }

  int get kubbsOutOfBounds {
    return rounds.fold(
      0,
      (sum, round) =>
          sum +
          round.inkastData.kubbsOutFirstAttempt +
          round.inkastData.kubbsOutSecondAttempt,
    );
  }

  int get totalBlastKubbs {
    return rounds.fold(0, (sum, round) => sum + round.blastData.hits);
  }

  double get overallHandicap {
    final roundsWithFieldKubbs =
        rounds.where((r) => r.roundNumber > 1).toList();
    if (roundsWithFieldKubbs.isEmpty) return 0.0;

    final totalHandicap = roundsWithFieldKubbs.fold<int>(
      0,
      (sum, round) => sum + (round.handicap ?? 0),
    );
    return totalHandicap / roundsWithFieldKubbs.length;
  }

  String get outcome {
    if (!isComplete) return 'In Progress';
    return kingHit ? 'Victory' : 'Defeat';
  }

  int get batonLimit {
    switch (currentRound) {
      case 1:
        return 2;
      case 2:
        return 4;
      default:
        return 6;
    }
  }

  bool get canProceedToNextPhase {
    final round = currentRoundData;
    if (round == null) return false;

    switch (currentPhase) {
      case FullGamePhase.attacking:
        return round.eightMeterData.isComplete;
      case FullGamePhase.inkast:
        return round.inkastData.isInkastComplete;
      case FullGamePhase.roundComplete:
        return true;
    }
  }

  // Session Management

  void addRound(FullGameSimRound round) {
    rounds.add(round);
    totalRounds++;
    totalInkastKubbs += round.inkastData.inkastKubbs;
    totalKubbsClearedFirstThrow += round.blastData.kubbsClearedFirstThrow;
    totalBatonsUsed += round.totalBatonsUsed;
    totalPenaltyKubbs += round.inkastData.penaltyKubbs;
    totalNeighborKubbs += round.inkastData.neighborKubbs;
    totalMisses += round.totalMisses;
    totalEightMeterHits += round.eightMeterData.hits;
    totalEightMeterBatons += round.eightMeterData.batonsUsed;
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

  void recordBaselineKubbsHit(int count) {
    if (currentAttackingTeam == 1) {
      team1BaselineKubbs = (team1BaselineKubbs - count).clamp(0, 5);
    } else {
      team2BaselineKubbs = (team2BaselineKubbs - count).clamp(0, 5);
    }
    modifiedAt = DateTime.now();
  }

  void nextPhase() {
    switch (currentPhase) {
      case FullGamePhase.attacking:
        if (currentRound == 1) {
          // Round 1 only has attacking phase
          currentPhase = FullGamePhase.roundComplete;
        } else {
          // Rounds 2+ have inkast phase
          currentPhase = FullGamePhase.inkast;
        }
        break;
      case FullGamePhase.inkast:
        currentPhase = FullGamePhase.attacking;
        break;
      case FullGamePhase.roundComplete:
        // Move to next round
        currentRound++;
        currentPhase = FullGamePhase.attacking;
        break;
    }
    modifiedAt = DateTime.now();
  }

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'isComplete': isComplete,
      'isPaused': isPaused,
      'currentRound': currentRound,
      'currentPhase': currentPhase.name,
      'totalRounds': totalRounds,
      'totalInkastKubbs': totalInkastKubbs,
      'totalKubbsClearedFirstThrow': totalKubbsClearedFirstThrow,
      'totalBatonsUsed': totalBatonsUsed,
      'totalPenaltyKubbs': totalPenaltyKubbs,
      'totalNeighborKubbs': totalNeighborKubbs,
      'totalMisses': totalMisses,
      'totalEightMeterHits': totalEightMeterHits,
      'totalEightMeterBatons': totalEightMeterBatons,
      'team1BaselineKubbs': team1BaselineKubbs,
      'team2BaselineKubbs': team2BaselineKubbs,
      'team1UnclearedKubbs': team1UnclearedKubbs,
      'team2UnclearedKubbs': team2UnclearedKubbs,
      'kingHit': kingHit,
      'rounds': rounds.map((r) => r.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'modifiedAt': modifiedAt.toIso8601String(),
    };
  }

  factory FullGameSimSession.fromJson(Map<String, dynamic> json) {
    return FullGameSimSession._(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      isComplete: json['isComplete'] as bool,
      isPaused: json['isPaused'] as bool,
      currentRound: json['currentRound'] as int,
      currentPhase: FullGamePhase.values.firstWhere(
        (e) => e.name == json['currentPhase'],
      ),
      totalRounds: json['totalRounds'] as int,
      totalInkastKubbs: json['totalInkastKubbs'] as int,
      totalKubbsClearedFirstThrow: json['totalKubbsClearedFirstThrow'] as int,
      totalBatonsUsed: json['totalBatonsUsed'] as int,
      totalPenaltyKubbs: json['totalPenaltyKubbs'] as int,
      totalNeighborKubbs: json['totalNeighborKubbs'] as int,
      totalMisses: json['totalMisses'] as int,
      totalEightMeterHits: json['totalEightMeterHits'] as int,
      totalEightMeterBatons: json['totalEightMeterBatons'] as int,
      team1BaselineKubbs: json['team1BaselineKubbs'] as int,
      team2BaselineKubbs: json['team2BaselineKubbs'] as int,
      team1UnclearedKubbs: json['team1UnclearedKubbs'] as int,
      team2UnclearedKubbs: json['team2UnclearedKubbs'] as int,
      kingHit: json['kingHit'] as bool,
      rounds: (json['rounds'] as List)
          .map((r) => FullGameSimRound.fromJson(r as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      modifiedAt: DateTime.parse(json['modifiedAt'] as String),
    );
  }
}

/// Represents a single round in a Full Game Simulation
class FullGameSimRound {
  final String id;
  final int roundNumber;
  EightMeterRoundData eightMeterData;
  InkastRoundData inkastData;
  BlastRoundData blastData;
  int baselineKubbsHit;
  bool isComplete;
  final DateTime createdAt;

  // A-Line tracking
  bool hasALine;
  int unclearedFieldKubbs;
  String? gamePhaseWhenALineAwarded;

  FullGameSimRound({
    String? id,
    required this.roundNumber,
  })  : id = id ?? const Uuid().v4(),
        eightMeterData = EightMeterRoundData(),
        inkastData = InkastRoundData(),
        blastData = BlastRoundData(),
        baselineKubbsHit = 0,
        isComplete = false,
        createdAt = DateTime.now(),
        hasALine = false,
        unclearedFieldKubbs = 0,
        gamePhaseWhenALineAwarded = null;

  FullGameSimRound._({
    required this.id,
    required this.roundNumber,
    required this.eightMeterData,
    required this.inkastData,
    required this.blastData,
    required this.baselineKubbsHit,
    required this.isComplete,
    required this.createdAt,
    required this.hasALine,
    required this.unclearedFieldKubbs,
    this.gamePhaseWhenALineAwarded,
  });

  // Computed Properties

  int get totalBatonsUsed =>
      eightMeterData.batonsUsed + inkastData.batonsUsed + blastData.batonsUsed;

  int get totalMisses =>
      eightMeterData.misses + inkastData.misses + blastData.misses;

  int get totalKubbsKnockedDown =>
      eightMeterData.hits + blastData.totalKubbsKnockedDown + baselineKubbsHit;

  int get totalHits =>
      eightMeterData.hits + inkastData.hits + blastData.hits;

  double get accuracy {
    if (totalBatonsUsed == 0) return 0.0;
    return totalHits / totalBatonsUsed;
  }

  double get eightMeterAccuracy => eightMeterData.accuracy;
  double get inkastAccuracy => inkastData.accuracy;
  double get blastAccuracy => blastData.accuracy;

  int? get handicap {
    if (roundNumber <= 1) return null; // Round 1 has no field kubbs
    final target = _calculateTargetBatons(inkastData.inkastKubbs);
    return blastData.batonsUsed - target;
  }

  int get fieldClearingMisses {
    if (roundNumber <= 1) return 0;
    return inkastData.misses + blastData.misses;
  }

  int _calculateTargetBatons(int inkastKubbs) {
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

  // Round Management

  void completeRound() {
    isComplete = true;
  }

  void resetRound() {
    eightMeterData = EightMeterRoundData();
    inkastData = InkastRoundData();
    blastData = BlastRoundData();
    isComplete = false;
  }

  // Serialization

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roundNumber': roundNumber,
      'eightMeterData': eightMeterData.toJson(),
      'inkastData': inkastData.toJson(),
      'blastData': blastData.toJson(),
      'baselineKubbsHit': baselineKubbsHit,
      'isComplete': isComplete,
      'createdAt': createdAt.toIso8601String(),
      'hasALine': hasALine,
      'unclearedFieldKubbs': unclearedFieldKubbs,
      'gamePhaseWhenALineAwarded': gamePhaseWhenALineAwarded,
    };
  }

  factory FullGameSimRound.fromJson(Map<String, dynamic> json) {
    return FullGameSimRound._(
      id: json['id'] as String,
      roundNumber: json['roundNumber'] as int,
      eightMeterData: EightMeterRoundData.fromJson(
          json['eightMeterData'] as Map<String, dynamic>),
      inkastData: InkastRoundData.fromJson(
          json['inkastData'] as Map<String, dynamic>),
      blastData:
          BlastRoundData.fromJson(json['blastData'] as Map<String, dynamic>),
      baselineKubbsHit: json['baselineKubbsHit'] as int,
      isComplete: json['isComplete'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      hasALine: json['hasALine'] as bool,
      unclearedFieldKubbs: json['unclearedFieldKubbs'] as int,
      gamePhaseWhenALineAwarded: json['gamePhaseWhenALineAwarded'] as String?,
    );
  }
}

/// Eight meter round data
class EightMeterRoundData {
  int hits;
  int misses;
  int batonsUsed;
  List<EightMeterBatonThrow> batonThrows;

  // A-Line statistics
  int hitsFromALine;
  int missesFromALine;
  int batonsUsedFromALine;

  EightMeterRoundData()
      : hits = 0,
        misses = 0,
        batonsUsed = 0,
        batonThrows = [],
        hitsFromALine = 0,
        missesFromALine = 0,
        batonsUsedFromALine = 0;

  EightMeterRoundData._({
    required this.hits,
    required this.misses,
    required this.batonsUsed,
    required this.batonThrows,
    required this.hitsFromALine,
    required this.missesFromALine,
    required this.batonsUsedFromALine,
  });

  bool get isComplete => batonsUsed >= 2;

  double get accuracy {
    if (batonsUsed == 0) return 0.0;
    return hits / batonsUsed;
  }

  double get accuracyFromALine {
    if (batonsUsedFromALine == 0) return 0.0;
    return hitsFromALine / batonsUsedFromALine;
  }

  void addBatonThrow({required bool isHit, bool fromALine = false}) {
    final batonThrow = EightMeterBatonThrow(
      isHit: isHit,
      throwNumber: batonThrows.length + 1,
      fromALine: fromALine,
    );
    batonThrows.add(batonThrow);

    batonsUsed++;

    if (isHit) {
      hits++;
    } else {
      misses++;
    }

    if (fromALine) {
      batonsUsedFromALine++;
      if (isHit) {
        hitsFromALine++;
      } else {
        missesFromALine++;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'hits': hits,
      'misses': misses,
      'batonsUsed': batonsUsed,
      'batonThrows': batonThrows.map((t) => t.toJson()).toList(),
      'hitsFromALine': hitsFromALine,
      'missesFromALine': missesFromALine,
      'batonsUsedFromALine': batonsUsedFromALine,
    };
  }

  factory EightMeterRoundData.fromJson(Map<String, dynamic> json) {
    return EightMeterRoundData._(
      hits: json['hits'] as int,
      misses: json['misses'] as int,
      batonsUsed: json['batonsUsed'] as int,
      batonThrows: (json['batonThrows'] as List)
          .map((t) =>
              EightMeterBatonThrow.fromJson(t as Map<String, dynamic>))
          .toList(),
      hitsFromALine: json['hitsFromALine'] as int? ?? 0,
      missesFromALine: json['missesFromALine'] as int? ?? 0,
      batonsUsedFromALine: json['batonsUsedFromALine'] as int? ?? 0,
    );
  }
}

/// Inkast round data
class InkastRoundData {
  int inkastKubbs;
  int kubbsOutFirstAttempt;
  int kubbsOutSecondAttempt;
  int penaltyKubbs;
  int neighborKubbs;
  int hits;
  int misses;
  int batonsUsed;
  List<InkastBatonThrow> batonThrows;

  InkastRoundData()
      : inkastKubbs = 0,
        kubbsOutFirstAttempt = 0,
        kubbsOutSecondAttempt = 0,
        penaltyKubbs = 0,
        neighborKubbs = 0,
        hits = 0,
        misses = 0,
        batonsUsed = 0,
        batonThrows = [];

  InkastRoundData._({
    required this.inkastKubbs,
    required this.kubbsOutFirstAttempt,
    required this.kubbsOutSecondAttempt,
    required this.penaltyKubbs,
    required this.neighborKubbs,
    required this.hits,
    required this.misses,
    required this.batonsUsed,
    required this.batonThrows,
  });

  bool get isInkastComplete =>
      kubbsOutFirstAttempt == 0 || kubbsOutSecondAttempt > 0;

  int get totalKubbsInBounds => inkastKubbs - penaltyKubbs;

  int get totalFieldKubbsForAttacking => inkastKubbs;

  double get accuracy {
    if (batonsUsed == 0) return 0.0;
    return hits / batonsUsed;
  }

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
      hits++;
    } else {
      misses++;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'inkastKubbs': inkastKubbs,
      'kubbsOutFirstAttempt': kubbsOutFirstAttempt,
      'kubbsOutSecondAttempt': kubbsOutSecondAttempt,
      'penaltyKubbs': penaltyKubbs,
      'neighborKubbs': neighborKubbs,
      'hits': hits,
      'misses': misses,
      'batonsUsed': batonsUsed,
      'batonThrows': batonThrows.map((t) => t.toJson()).toList(),
    };
  }

  factory InkastRoundData.fromJson(Map<String, dynamic> json) {
    return InkastRoundData._(
      inkastKubbs: json['inkastKubbs'] as int,
      kubbsOutFirstAttempt: json['kubbsOutFirstAttempt'] as int,
      kubbsOutSecondAttempt: json['kubbsOutSecondAttempt'] as int,
      penaltyKubbs: json['penaltyKubbs'] as int,
      neighborKubbs: json['neighborKubbs'] as int,
      hits: json['hits'] as int,
      misses: json['misses'] as int,
      batonsUsed: json['batonsUsed'] as int,
      batonThrows: (json['batonThrows'] as List)
          .map((t) => InkastBatonThrow.fromJson(t as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Blast round data
class BlastRoundData {
  int kubbsClearedFirstThrow;
  int hits;
  int misses;
  int batonsUsed;
  List<BlastBatonThrow> batonThrows;

  // A-Line statistics
  int hitsFromALine;
  int missesFromALine;
  int batonsUsedFromALine;

  BlastRoundData()
      : kubbsClearedFirstThrow = 0,
        hits = 0,
        misses = 0,
        batonsUsed = 0,
        batonThrows = [],
        hitsFromALine = 0,
        missesFromALine = 0,
        batonsUsedFromALine = 0;

  BlastRoundData._({
    required this.kubbsClearedFirstThrow,
    required this.hits,
    required this.misses,
    required this.batonsUsed,
    required this.batonThrows,
    required this.hitsFromALine,
    required this.missesFromALine,
    required this.batonsUsedFromALine,
  });

  bool get isComplete => kubbsClearedFirstThrow >= 5;

  int get totalKubbsKnockedDown {
    return batonThrows.fold(
      0,
      (sum, batonThrow) => sum + (batonThrow.isHit ? batonThrow.kubbsHit : 0),
    );
  }

  double get accuracy {
    if (batonsUsed == 0) return 0.0;
    return hits / batonsUsed;
  }

  double get accuracyFromALine {
    if (batonsUsedFromALine == 0) return 0.0;
    return hitsFromALine / batonsUsedFromALine;
  }

  void addBatonThrow({
    required bool isHit,
    int kubbsHit = 0,
    bool fromALine = false,
  }) {
    final batonThrow = BlastBatonThrow(
      isHit: isHit,
      kubbsHit: kubbsHit,
      throwNumber: batonThrows.length + 1,
      fromALine: fromALine,
    );
    batonThrows.add(batonThrow);

    batonsUsed++;

    if (isHit) {
      hits++;
      kubbsClearedFirstThrow += kubbsHit;
    } else {
      misses++;
    }

    if (fromALine) {
      batonsUsedFromALine++;
      if (isHit) {
        hitsFromALine++;
      } else {
        missesFromALine++;
      }
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'kubbsClearedFirstThrow': kubbsClearedFirstThrow,
      'hits': hits,
      'misses': misses,
      'batonsUsed': batonsUsed,
      'batonThrows': batonThrows.map((t) => t.toJson()).toList(),
      'hitsFromALine': hitsFromALine,
      'missesFromALine': missesFromALine,
      'batonsUsedFromALine': batonsUsedFromALine,
    };
  }

  factory BlastRoundData.fromJson(Map<String, dynamic> json) {
    return BlastRoundData._(
      kubbsClearedFirstThrow: json['kubbsClearedFirstThrow'] as int,
      hits: json['hits'] as int,
      misses: json['misses'] as int,
      batonsUsed: json['batonsUsed'] as int,
      batonThrows: (json['batonThrows'] as List)
          .map((t) => BlastBatonThrow.fromJson(t as Map<String, dynamic>))
          .toList(),
      hitsFromALine: json['hitsFromALine'] as int? ?? 0,
      missesFromALine: json['missesFromALine'] as int? ?? 0,
      batonsUsedFromALine: json['batonsUsedFromALine'] as int? ?? 0,
    );
  }
}

// Baton Throw Data Structures

class EightMeterBatonThrow {
  final String id;
  final bool isHit;
  final int throwNumber;
  final DateTime timestamp;
  final bool fromALine;

  EightMeterBatonThrow({
    String? id,
    required this.isHit,
    required this.throwNumber,
    this.fromALine = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = DateTime.now();

  EightMeterBatonThrow._({
    required this.id,
    required this.isHit,
    required this.throwNumber,
    required this.timestamp,
    required this.fromALine,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isHit': isHit,
      'throwNumber': throwNumber,
      'timestamp': timestamp.toIso8601String(),
      'fromALine': fromALine,
    };
  }

  factory EightMeterBatonThrow.fromJson(Map<String, dynamic> json) {
    return EightMeterBatonThrow._(
      id: json['id'] as String,
      isHit: json['isHit'] as bool,
      throwNumber: json['throwNumber'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fromALine: json['fromALine'] as bool? ?? false,
    );
  }
}

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

class BlastBatonThrow {
  final String id;
  final bool isHit;
  final int kubbsHit;
  final int throwNumber;
  final DateTime timestamp;
  final bool fromALine;

  BlastBatonThrow({
    String? id,
    required this.isHit,
    required this.kubbsHit,
    required this.throwNumber,
    this.fromALine = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = DateTime.now();

  BlastBatonThrow._({
    required this.id,
    required this.isHit,
    required this.kubbsHit,
    required this.throwNumber,
    required this.timestamp,
    required this.fromALine,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isHit': isHit,
      'kubbsHit': kubbsHit,
      'throwNumber': throwNumber,
      'timestamp': timestamp.toIso8601String(),
      'fromALine': fromALine,
    };
  }

  factory BlastBatonThrow.fromJson(Map<String, dynamic> json) {
    return BlastBatonThrow._(
      id: json['id'] as String,
      isHit: json['isHit'] as bool,
      kubbsHit: json['kubbsHit'] as int,
      throwNumber: json['throwNumber'] as int,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fromALine: json['fromALine'] as bool? ?? false,
    );
  }
}

