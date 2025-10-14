import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/practice_session.dart';
import '../models/inkast_blast_session.dart';
import '../models/full_game_sim_session.dart';

/// Database service for managing local storage of all session types
class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  /// Get or create the database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kubb_manager.db');
    return _database!;
  }

  /// Initialize the database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    // Practice Sessions table (8 Meter Practice)
    await db.execute('''
      CREATE TABLE practice_sessions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        target INTEGER NOT NULL,
        totalKubbs INTEGER NOT NULL,
        totalBatons INTEGER NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        isComplete INTEGER NOT NULL,
        isPaused INTEGER NOT NULL,
        rounds TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        modifiedAt TEXT NOT NULL
      )
    ''');

    // Inkast Blast Sessions table
    await db.execute('''
      CREATE TABLE inkast_blast_sessions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        gamePhase TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        isComplete INTEGER NOT NULL,
        isPaused INTEGER NOT NULL,
        totalRounds INTEGER NOT NULL,
        totalInkastKubbs INTEGER NOT NULL,
        totalKubbsClearedFirstThrow INTEGER NOT NULL,
        totalBatonsUsed INTEGER NOT NULL,
        totalPenaltyKubbs INTEGER NOT NULL,
        totalNeighborKubbs INTEGER NOT NULL,
        totalMisses INTEGER NOT NULL,
        rounds TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        modifiedAt TEXT NOT NULL
      )
    ''');

    // Full Game Sim Sessions table
    await db.execute('''
      CREATE TABLE full_game_sim_sessions (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        startTime TEXT NOT NULL,
        endTime TEXT,
        isComplete INTEGER NOT NULL,
        isPaused INTEGER NOT NULL,
        currentRound INTEGER NOT NULL,
        currentPhase TEXT NOT NULL,
        totalRounds INTEGER NOT NULL,
        totalInkastKubbs INTEGER NOT NULL,
        totalKubbsClearedFirstThrow INTEGER NOT NULL,
        totalBatonsUsed INTEGER NOT NULL,
        totalPenaltyKubbs INTEGER NOT NULL,
        totalNeighborKubbs INTEGER NOT NULL,
        totalMisses INTEGER NOT NULL,
        totalEightMeterHits INTEGER NOT NULL,
        totalEightMeterBatons INTEGER NOT NULL,
        team1BaselineKubbs INTEGER NOT NULL,
        team2BaselineKubbs INTEGER NOT NULL,
        team1UnclearedKubbs INTEGER NOT NULL,
        team2UnclearedKubbs INTEGER NOT NULL,
        kingHit INTEGER NOT NULL,
        rounds TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        modifiedAt TEXT NOT NULL
      )
    ''');

    // Create indexes for faster queries
    await db.execute(
        'CREATE INDEX idx_practice_date ON practice_sessions(date DESC)');
    await db.execute(
        'CREATE INDEX idx_inkast_date ON inkast_blast_sessions(date DESC)');
    await db.execute(
        'CREATE INDEX idx_fullgame_date ON full_game_sim_sessions(date DESC)');
  }

  /// Handle database upgrades
  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    // Handle schema migrations in future versions
    if (oldVersion < 2) {
      // Example migration for version 2
      // await db.execute('ALTER TABLE practice_sessions ADD COLUMN new_field TEXT');
    }
  }

  // ==================== PRACTICE SESSION OPERATIONS ====================

  /// Create a new practice session
  Future<PracticeSession> createPracticeSession(
      PracticeSession session) async {
    final db = await database;
    await db.insert('practice_sessions', _practiceSessionToMap(session));
    return session;
  }

  /// Read a practice session by ID
  Future<PracticeSession?> readPracticeSession(String id) async {
    final db = await database;
    final maps = await db.query(
      'practice_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _practiceSessionFromMap(maps.first);
    }
    return null;
  }

  /// Read all practice sessions
  Future<List<PracticeSession>> readAllPracticeSessions() async {
    final db = await database;
    final maps = await db.query(
      'practice_sessions',
      orderBy: 'date DESC',
    );

    return maps.map((map) => _practiceSessionFromMap(map)).toList();
  }

  /// Update a practice session
  Future<int> updatePracticeSession(PracticeSession session) async {
    final db = await database;
    return await db.update(
      'practice_sessions',
      _practiceSessionToMap(session),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Delete a practice session
  Future<int> deletePracticeSession(String id) async {
    final db = await database;
    return await db.delete(
      'practice_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get practice sessions by date range
  Future<List<PracticeSession>> getPracticeSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'practice_sessions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );

    return maps.map((map) => _practiceSessionFromMap(map)).toList();
  }

  // ==================== INKAST BLAST SESSION OPERATIONS ====================

  /// Create a new inkast blast session
  Future<InkastBlastSession> createInkastBlastSession(
      InkastBlastSession session) async {
    final db = await database;
    await db.insert('inkast_blast_sessions', _inkastBlastSessionToMap(session));
    return session;
  }

  /// Read an inkast blast session by ID
  Future<InkastBlastSession?> readInkastBlastSession(String id) async {
    final db = await database;
    final maps = await db.query(
      'inkast_blast_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _inkastBlastSessionFromMap(maps.first);
    }
    return null;
  }

  /// Read all inkast blast sessions
  Future<List<InkastBlastSession>> readAllInkastBlastSessions() async {
    final db = await database;
    final maps = await db.query(
      'inkast_blast_sessions',
      orderBy: 'date DESC',
    );

    return maps.map((map) => _inkastBlastSessionFromMap(map)).toList();
  }

  /// Update an inkast blast session
  Future<int> updateInkastBlastSession(InkastBlastSession session) async {
    final db = await database;
    return await db.update(
      'inkast_blast_sessions',
      _inkastBlastSessionToMap(session),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Delete an inkast blast session
  Future<int> deleteInkastBlastSession(String id) async {
    final db = await database;
    return await db.delete(
      'inkast_blast_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get inkast blast sessions by date range
  Future<List<InkastBlastSession>> getInkastBlastSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'inkast_blast_sessions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );

    return maps.map((map) => _inkastBlastSessionFromMap(map)).toList();
  }

  // ==================== FULL GAME SIM SESSION OPERATIONS ====================

  /// Create a new full game sim session
  Future<FullGameSimSession> createFullGameSimSession(
      FullGameSimSession session) async {
    final db = await database;
    await db.insert(
        'full_game_sim_sessions', _fullGameSimSessionToMap(session));
    return session;
  }

  /// Read a full game sim session by ID
  Future<FullGameSimSession?> readFullGameSimSession(String id) async {
    final db = await database;
    final maps = await db.query(
      'full_game_sim_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return _fullGameSimSessionFromMap(maps.first);
    }
    return null;
  }

  /// Read all full game sim sessions
  Future<List<FullGameSimSession>> readAllFullGameSimSessions() async {
    final db = await database;
    final maps = await db.query(
      'full_game_sim_sessions',
      orderBy: 'date DESC',
    );

    return maps.map((map) => _fullGameSimSessionFromMap(map)).toList();
  }

  /// Update a full game sim session
  Future<int> updateFullGameSimSession(FullGameSimSession session) async {
    final db = await database;
    return await db.update(
      'full_game_sim_sessions',
      _fullGameSimSessionToMap(session),
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  /// Delete a full game sim session
  Future<int> deleteFullGameSimSession(String id) async {
    final db = await database;
    return await db.delete(
      'full_game_sim_sessions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get full game sim sessions by date range
  Future<List<FullGameSimSession>> getFullGameSimSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    final db = await database;
    final maps = await db.query(
      'full_game_sim_sessions',
      where: 'date BETWEEN ? AND ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date DESC',
    );

    return maps.map((map) => _fullGameSimSessionFromMap(map)).toList();
  }

  // ==================== UTILITY METHODS ====================

  /// Get total session count across all types
  Future<Map<String, int>> getSessionCounts() async {
    final db = await database;

    final practiceCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM practice_sessions'),
    );
    final inkastCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM inkast_blast_sessions'),
    );
    final fullGameCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM full_game_sim_sessions'),
    );

    return {
      'practice': practiceCount ?? 0,
      'inkastBlast': inkastCount ?? 0,
      'fullGameSim': fullGameCount ?? 0,
      'total': (practiceCount ?? 0) + (inkastCount ?? 0) + (fullGameCount ?? 0),
    };
  }

  /// Delete all sessions (useful for testing or reset)
  Future<void> deleteAllSessions() async {
    final db = await database;
    await db.delete('practice_sessions');
    await db.delete('inkast_blast_sessions');
    await db.delete('full_game_sim_sessions');
  }

  /// Close the database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // ==================== SERIALIZATION HELPERS ====================

  /// Convert PracticeSession to database map
  Map<String, dynamic> _practiceSessionToMap(PracticeSession session) {
    return {
      'id': session.id,
      'date': session.date.toIso8601String(),
      'target': session.target,
      'totalKubbs': session.totalKubbs,
      'totalBatons': session.totalBatons,
      'startTime': session.startTime.toIso8601String(),
      'endTime': session.endTime?.toIso8601String(),
      'isComplete': session.isComplete ? 1 : 0,
      'isPaused': session.isPaused ? 1 : 0,
      'rounds': jsonEncode(session.rounds.map((r) => r.toJson()).toList()),
      'createdAt': session.createdAt.toIso8601String(),
      'modifiedAt': session.modifiedAt.toIso8601String(),
    };
  }

  /// Convert database map to PracticeSession
  PracticeSession _practiceSessionFromMap(Map<String, dynamic> map) {
    return PracticeSession.fromJson({
      'id': map['id'],
      'date': map['date'],
      'target': map['target'],
      'totalKubbs': map['totalKubbs'],
      'totalBatons': map['totalBatons'],
      'startTime': map['startTime'],
      'endTime': map['endTime'],
      'isComplete': map['isComplete'] == 1,
      'isPaused': map['isPaused'] == 1,
      'rounds': jsonDecode(map['rounds']),
      'createdAt': map['createdAt'],
      'modifiedAt': map['modifiedAt'],
    });
  }

  /// Convert InkastBlastSession to database map
  Map<String, dynamic> _inkastBlastSessionToMap(InkastBlastSession session) {
    return {
      'id': session.id,
      'date': session.date.toIso8601String(),
      'gamePhase': session.gamePhase.name,
      'startTime': session.startTime.toIso8601String(),
      'endTime': session.endTime?.toIso8601String(),
      'isComplete': session.isComplete ? 1 : 0,
      'isPaused': session.isPaused ? 1 : 0,
      'totalRounds': session.totalRounds,
      'totalInkastKubbs': session.totalInkastKubbs,
      'totalKubbsClearedFirstThrow': session.totalKubbsClearedFirstThrow,
      'totalBatonsUsed': session.totalBatonsUsed,
      'totalPenaltyKubbs': session.totalPenaltyKubbs,
      'totalNeighborKubbs': session.totalNeighborKubbs,
      'totalMisses': session.totalMisses,
      'rounds': jsonEncode(session.rounds.map((r) => r.toJson()).toList()),
      'createdAt': session.createdAt.toIso8601String(),
      'modifiedAt': session.modifiedAt.toIso8601String(),
    };
  }

  /// Convert database map to InkastBlastSession
  InkastBlastSession _inkastBlastSessionFromMap(Map<String, dynamic> map) {
    return InkastBlastSession.fromJson({
      'id': map['id'],
      'date': map['date'],
      'gamePhase': map['gamePhase'],
      'startTime': map['startTime'],
      'endTime': map['endTime'],
      'isComplete': map['isComplete'] == 1,
      'isPaused': map['isPaused'] == 1,
      'totalRounds': map['totalRounds'],
      'totalInkastKubbs': map['totalInkastKubbs'],
      'totalKubbsClearedFirstThrow': map['totalKubbsClearedFirstThrow'],
      'totalBatonsUsed': map['totalBatonsUsed'],
      'totalPenaltyKubbs': map['totalPenaltyKubbs'],
      'totalNeighborKubbs': map['totalNeighborKubbs'],
      'totalMisses': map['totalMisses'],
      'rounds': jsonDecode(map['rounds']),
      'createdAt': map['createdAt'],
      'modifiedAt': map['modifiedAt'],
    });
  }

  /// Convert FullGameSimSession to database map
  Map<String, dynamic> _fullGameSimSessionToMap(FullGameSimSession session) {
    return {
      'id': session.id,
      'date': session.date.toIso8601String(),
      'startTime': session.startTime.toIso8601String(),
      'endTime': session.endTime?.toIso8601String(),
      'isComplete': session.isComplete ? 1 : 0,
      'isPaused': session.isPaused ? 1 : 0,
      'currentRound': session.currentRound,
      'currentPhase': session.currentPhase.name,
      'totalRounds': session.totalRounds,
      'totalInkastKubbs': session.totalInkastKubbs,
      'totalKubbsClearedFirstThrow': session.totalKubbsClearedFirstThrow,
      'totalBatonsUsed': session.totalBatonsUsed,
      'totalPenaltyKubbs': session.totalPenaltyKubbs,
      'totalNeighborKubbs': session.totalNeighborKubbs,
      'totalMisses': session.totalMisses,
      'totalEightMeterHits': session.totalEightMeterHits,
      'totalEightMeterBatons': session.totalEightMeterBatons,
      'team1BaselineKubbs': session.team1BaselineKubbs,
      'team2BaselineKubbs': session.team2BaselineKubbs,
      'team1UnclearedKubbs': session.team1UnclearedKubbs,
      'team2UnclearedKubbs': session.team2UnclearedKubbs,
      'kingHit': session.kingHit ? 1 : 0,
      'rounds': jsonEncode(session.rounds.map((r) => r.toJson()).toList()),
      'createdAt': session.createdAt.toIso8601String(),
      'modifiedAt': session.modifiedAt.toIso8601String(),
    };
  }

  /// Convert database map to FullGameSimSession
  FullGameSimSession _fullGameSimSessionFromMap(Map<String, dynamic> map) {
    return FullGameSimSession.fromJson({
      'id': map['id'],
      'date': map['date'],
      'startTime': map['startTime'],
      'endTime': map['endTime'],
      'isComplete': map['isComplete'] == 1,
      'isPaused': map['isPaused'] == 1,
      'currentRound': map['currentRound'],
      'currentPhase': map['currentPhase'],
      'totalRounds': map['totalRounds'],
      'totalInkastKubbs': map['totalInkastKubbs'],
      'totalKubbsClearedFirstThrow': map['totalKubbsClearedFirstThrow'],
      'totalBatonsUsed': map['totalBatonsUsed'],
      'totalPenaltyKubbs': map['totalPenaltyKubbs'],
      'totalNeighborKubbs': map['totalNeighborKubbs'],
      'totalMisses': map['totalMisses'],
      'totalEightMeterHits': map['totalEightMeterHits'],
      'totalEightMeterBatons': map['totalEightMeterBatons'],
      'team1BaselineKubbs': map['team1BaselineKubbs'],
      'team2BaselineKubbs': map['team2BaselineKubbs'],
      'team1UnclearedKubbs': map['team1UnclearedKubbs'],
      'team2UnclearedKubbs': map['team2UnclearedKubbs'],
      'kingHit': map['kingHit'] == 1,
      'rounds': jsonDecode(map['rounds']),
      'createdAt': map['createdAt'],
      'modifiedAt': map['modifiedAt'],
    });
  }
}

