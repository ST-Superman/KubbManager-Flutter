import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/practice_session.dart';
import '../models/inkast_blast_session.dart';
import '../models/full_game_sim_session.dart';
import 'database_service.dart';

/// Manages active sessions and app lifecycle
class SessionManager extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  // Active session IDs
  String? _activePracticeSessionId;
  String? _activeInkastBlastSessionId;
  String? _activeFullGameSimSessionId;

  // Cached active sessions
  PracticeSession? _activePracticeSession;
  InkastBlastSession? _activeInkastBlastSession;
  FullGameSimSession? _activeFullGameSimSession;

  // SharedPreferences keys
  static const String _keyActivePracticeSession = 'active_practice_session_id';
  static const String _keyActiveInkastBlastSession =
      'active_inkast_blast_session_id';
  static const String _keyActiveFullGameSimSession =
      'active_full_game_sim_session_id';

  SessionManager() {
    _loadActiveSessionIds();
  }

  // ==================== GETTERS ====================

  PracticeSession? get activePracticeSession => _activePracticeSession;
  InkastBlastSession? get activeInkastBlastSession =>
      _activeInkastBlastSession;
  FullGameSimSession? get activeFullGameSimSession =>
      _activeFullGameSimSession;

  bool get hasActivePracticeSession => _activePracticeSession != null;
  bool get hasActiveInkastBlastSession => _activeInkastBlastSession != null;
  bool get hasActiveFullGameSimSession => _activeFullGameSimSession != null;

  // ==================== PRACTICE SESSION MANAGEMENT ====================

  /// Start a new practice session
  Future<PracticeSession> startPracticeSession({
    required int target,
    SessionType sessionType = SessionType.standard,
    int? targetScore,
  }) async {
    // Complete any existing active session
    if (_activePracticeSession != null) {
      await _autoCompletePracticeSession();
    }

    // Create new session
    final session = PracticeSession(
      target: target,
      sessionType: sessionType,
      targetScore: targetScore,
    );
    await _db.createPracticeSession(session);

    // Set as active
    _activePracticeSession = session;
    _activePracticeSessionId = session.id;
    await _saveActiveSessionId(_keyActivePracticeSession, session.id);

    notifyListeners();
    return session;
  }

  /// Resume an existing practice session
  Future<PracticeSession?> resumePracticeSession(String sessionId) async {
    final session = await _db.readPracticeSession(sessionId);
    if (session != null) {
      session.resumeSession();
      await _db.updatePracticeSession(session);

      _activePracticeSession = session;
      _activePracticeSessionId = session.id;
      await _saveActiveSessionId(_keyActivePracticeSession, session.id);

      notifyListeners();
    }
    return session;
  }

  /// Update the active practice session
  Future<void> updatePracticeSession(PracticeSession session) async {
    await _db.updatePracticeSession(session);
    _activePracticeSession = session;
    notifyListeners();
  }

  /// Complete the active practice session
  Future<void> completePracticeSession() async {
    if (_activePracticeSession == null) return;

    _activePracticeSession!.completeSession();
    await _db.updatePracticeSession(_activePracticeSession!);

    // Clear active session
    _activePracticeSession = null;
    _activePracticeSessionId = null;
    await _clearActiveSessionId(_keyActivePracticeSession);

    notifyListeners();
  }

  /// Pause the active practice session
  Future<void> pausePracticeSession() async {
    if (_activePracticeSession == null) return;

    _activePracticeSession!.pauseSession();
    await _db.updatePracticeSession(_activePracticeSession!);
    notifyListeners();
  }

  /// Auto-complete practice session (when starting a new one or app lifecycle)
  Future<void> _autoCompletePracticeSession() async {
    if (_activePracticeSession == null) return;

    final completed = _activePracticeSession!.withAutoCompletion();
    await _db.updatePracticeSession(completed);

    _activePracticeSession = null;
    _activePracticeSessionId = null;
    await _clearActiveSessionId(_keyActivePracticeSession);
  }

  // ==================== INKAST BLAST SESSION MANAGEMENT ====================

  /// Start a new inkast blast session
  Future<InkastBlastSession> startInkastBlastSession({
    required GamePhase gamePhase,
  }) async {
    // Complete any existing active session
    if (_activeInkastBlastSession != null) {
      await completeInkastBlastSession();
    }

    // Create new session
    final session = InkastBlastSession(gamePhase: gamePhase);
    await _db.createInkastBlastSession(session);

    // Set as active
    _activeInkastBlastSession = session;
    _activeInkastBlastSessionId = session.id;
    await _saveActiveSessionId(_keyActiveInkastBlastSession, session.id);

    notifyListeners();
    return session;
  }

  /// Resume an existing inkast blast session
  Future<InkastBlastSession?> resumeInkastBlastSession(String sessionId) async {
    final session = await _db.readInkastBlastSession(sessionId);
    if (session != null) {
      session.resumeSession();
      await _db.updateInkastBlastSession(session);

      _activeInkastBlastSession = session;
      _activeInkastBlastSessionId = session.id;
      await _saveActiveSessionId(_keyActiveInkastBlastSession, session.id);

      notifyListeners();
    }
    return session;
  }

  /// Update the active inkast blast session
  Future<void> updateInkastBlastSession(InkastBlastSession session) async {
    await _db.updateInkastBlastSession(session);
    _activeInkastBlastSession = session;
    notifyListeners();
  }

  /// Complete the active inkast blast session
  Future<void> completeInkastBlastSession() async {
    if (_activeInkastBlastSession == null) return;

    _activeInkastBlastSession!.completeSession();
    await _db.updateInkastBlastSession(_activeInkastBlastSession!);

    // Clear active session
    _activeInkastBlastSession = null;
    _activeInkastBlastSessionId = null;
    await _clearActiveSessionId(_keyActiveInkastBlastSession);

    notifyListeners();
  }

  /// Pause the active inkast blast session
  Future<void> pauseInkastBlastSession() async {
    if (_activeInkastBlastSession == null) return;

    _activeInkastBlastSession!.pauseSession();
    await _db.updateInkastBlastSession(_activeInkastBlastSession!);
    notifyListeners();
  }

  // ==================== FULL GAME SIM SESSION MANAGEMENT ====================

  /// Start a new full game sim session
  Future<FullGameSimSession> startFullGameSimSession() async {
    // Complete any existing active session
    if (_activeFullGameSimSession != null) {
      await completeFullGameSimSession();
    }

    // Create new session
    final session = FullGameSimSession();
    await _db.createFullGameSimSession(session);

    // Set as active
    _activeFullGameSimSession = session;
    _activeFullGameSimSessionId = session.id;
    await _saveActiveSessionId(_keyActiveFullGameSimSession, session.id);

    notifyListeners();
    return session;
  }

  /// Resume an existing full game sim session
  Future<FullGameSimSession?> resumeFullGameSimSession(String sessionId) async {
    final session = await _db.readFullGameSimSession(sessionId);
    if (session != null) {
      session.resumeSession();
      await _db.updateFullGameSimSession(session);

      _activeFullGameSimSession = session;
      _activeFullGameSimSessionId = session.id;
      await _saveActiveSessionId(_keyActiveFullGameSimSession, session.id);

      notifyListeners();
    }
    return session;
  }

  /// Update the active full game sim session
  Future<void> updateFullGameSimSession(FullGameSimSession session) async {
    await _db.updateFullGameSimSession(session);
    _activeFullGameSimSession = session;
    notifyListeners();
  }

  /// Complete the active full game sim session
  Future<void> completeFullGameSimSession() async {
    if (_activeFullGameSimSession == null) return;

    _activeFullGameSimSession!.completeSession();
    await _db.updateFullGameSimSession(_activeFullGameSimSession!);

    // Clear active session
    _activeFullGameSimSession = null;
    _activeFullGameSimSessionId = null;
    await _clearActiveSessionId(_keyActiveFullGameSimSession);

    notifyListeners();
  }

  /// Pause the active full game sim session
  Future<void> pauseFullGameSimSession() async {
    if (_activeFullGameSimSession == null) return;

    _activeFullGameSimSession!.pauseSession();
    await _db.updateFullGameSimSession(_activeFullGameSimSession!);
    notifyListeners();
  }

  // ==================== SESSION HISTORY ====================

  /// Get all practice sessions
  Future<List<PracticeSession>> getAllPracticeSessions() async {
    return await _db.readAllPracticeSessions();
  }

  /// Get all inkast blast sessions
  Future<List<InkastBlastSession>> getAllInkastBlastSessions() async {
    return await _db.readAllInkastBlastSessions();
  }

  /// Get all full game sim sessions
  Future<List<FullGameSimSession>> getAllFullGameSimSessions() async {
    return await _db.readAllFullGameSimSessions();
  }

  /// Get practice sessions by date range
  Future<List<PracticeSession>> getPracticeSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _db.getPracticeSessionsByDateRange(startDate, endDate);
  }

  /// Get inkast blast sessions by date range
  Future<List<InkastBlastSession>> getInkastBlastSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _db.getInkastBlastSessionsByDateRange(startDate, endDate);
  }

  /// Get full game sim sessions by date range
  Future<List<FullGameSimSession>> getFullGameSimSessionsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await _db.getFullGameSimSessionsByDateRange(startDate, endDate);
  }

  /// Delete a practice session
  Future<void> deletePracticeSession(String id) async {
    await _db.deletePracticeSession(id);
    if (_activePracticeSessionId == id) {
      _activePracticeSession = null;
      _activePracticeSessionId = null;
      await _clearActiveSessionId(_keyActivePracticeSession);
    }
    notifyListeners();
  }

  /// Delete an inkast blast session
  Future<void> deleteInkastBlastSession(String id) async {
    await _db.deleteInkastBlastSession(id);
    if (_activeInkastBlastSessionId == id) {
      _activeInkastBlastSession = null;
      _activeInkastBlastSessionId = null;
      await _clearActiveSessionId(_keyActiveInkastBlastSession);
    }
    notifyListeners();
  }

  /// Delete a full game sim session
  Future<void> deleteFullGameSimSession(String id) async {
    await _db.deleteFullGameSimSession(id);
    if (_activeFullGameSimSessionId == id) {
      _activeFullGameSimSession = null;
      _activeFullGameSimSessionId = null;
      await _clearActiveSessionId(_keyActiveFullGameSimSession);
    }
    notifyListeners();
  }

  // ==================== APP LIFECYCLE MANAGEMENT ====================

  /// Handle app going to background
  Future<void> handleAppDidEnterBackground() async {
    // Auto-save all active sessions
    if (_activePracticeSession != null) {
      await updatePracticeSession(_activePracticeSession!);
    }
    if (_activeInkastBlastSession != null) {
      await updateInkastBlastSession(_activeInkastBlastSession!);
    }
    if (_activeFullGameSimSession != null) {
      await updateFullGameSimSession(_activeFullGameSimSession!);
    }
  }

  /// Handle app becoming inactive (e.g., phone call, notification)
  Future<void> handleAppWillResignActive() async {
    // Quick save of active sessions
    await handleAppDidEnterBackground();
  }

  /// Handle app coming to foreground
  Future<void> handleAppDidBecomeActive() async {
    // Check if any sessions need auto-completion (from previous days)
    if (_activePracticeSession != null) {
      final completed = _activePracticeSession!.withAutoCompletion();
      if (completed.isComplete && !_activePracticeSession!.isComplete) {
        await updatePracticeSession(completed);
        await _autoCompletePracticeSession();
      }
    }
  }

  // ==================== PERSISTENCE HELPERS ====================

  /// Load active session IDs from SharedPreferences
  Future<void> _loadActiveSessionIds() async {
    final prefs = await SharedPreferences.getInstance();

    _activePracticeSessionId = prefs.getString(_keyActivePracticeSession);
    _activeInkastBlastSessionId =
        prefs.getString(_keyActiveInkastBlastSession);
    _activeFullGameSimSessionId =
        prefs.getString(_keyActiveFullGameSimSession);

    // Load actual sessions from database
    if (_activePracticeSessionId != null) {
      _activePracticeSession =
          await _db.readPracticeSession(_activePracticeSessionId!);
      if (_activePracticeSession == null) {
        await _clearActiveSessionId(_keyActivePracticeSession);
      }
    }

    if (_activeInkastBlastSessionId != null) {
      _activeInkastBlastSession =
          await _db.readInkastBlastSession(_activeInkastBlastSessionId!);
      if (_activeInkastBlastSession == null) {
        await _clearActiveSessionId(_keyActiveInkastBlastSession);
      }
    }

    if (_activeFullGameSimSessionId != null) {
      _activeFullGameSimSession =
          await _db.readFullGameSimSession(_activeFullGameSimSessionId!);
      if (_activeFullGameSimSession == null) {
        await _clearActiveSessionId(_keyActiveFullGameSimSession);
      }
    }

    notifyListeners();
  }

  /// Save active session ID to SharedPreferences
  Future<void> _saveActiveSessionId(String key, String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, sessionId);
  }

  /// Clear active session ID from SharedPreferences
  Future<void> _clearActiveSessionId(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }

  // ==================== STATISTICS ====================

  /// Get session counts across all types
  Future<Map<String, int>> getSessionCounts() async {
    return await _db.getSessionCounts();
  }
}

