import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/practice_session.dart';
import '../services/session_manager.dart';
import '../services/watch_connectivity_service.dart';
import '../services/watch_session_helper.dart';
import '../models/watch_session_state.dart';

/// 8 Meter Practice Training View with Apple Watch Support
class EightMeterTrainingViewWithWatch extends StatefulWidget {
  const EightMeterTrainingViewWithWatch({super.key});

  @override
  State<EightMeterTrainingViewWithWatch> createState() =>
      _EightMeterTrainingViewWithWatchState();
}

class _EightMeterTrainingViewWithWatchState
    extends State<EightMeterTrainingViewWithWatch> with WidgetsBindingObserver {
  PracticeSession? _session;
  bool _isLoading = false;
  int _currentStreak = 0;
  int _bestStreak = 0;
  List<double> _accuracyHistory = [];
  
  // Watch connectivity
  final WatchConnectivityService _watchService = WatchConnectivityService();
  bool _isWatchModeEnabled = false;
  bool _isWatchConnected = false;
  StreamSubscription<WatchThrowEvent>? _throwEventSubscription;
  StreamSubscription<bool>? _connectionStateSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWatchConnectivity();
    _checkForActiveSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupWatchConnectivity();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && _isWatchModeEnabled) {
      debugPrint('🔵 App paused with watch mode active');
    } else if (state == AppLifecycleState.resumed && _isWatchModeEnabled) {
      debugPrint('🔵 App resumed with watch mode active');
      _syncSessionToWatch();
    }
  }

  // ============================================================================
  // Watch Connectivity Methods
  // ============================================================================

  Future<void> _initializeWatchConnectivity() async {
    final initialized = await _watchService.initialize();
    
    if (!initialized) {
      debugPrint('⚠️ Watch connectivity not available');
      return;
    }

    // Listen for connection state changes
    _connectionStateSubscription = _watchService.connectionState.listen((isConnected) {
      setState(() {
        _isWatchConnected = isConnected;
      });
      
      if (!isConnected && _isWatchModeEnabled) {
        _showSnackBar('Apple Watch disconnected', isError: true);
      }
    });

    // Listen for throw events from watch
    _throwEventSubscription = _watchService.throwEvents.listen((event) {
      if (event.sessionId == _session?.id) {
        _handleWatchThrow(event);
      }
    });

    // Listen for errors
    _errorSubscription = _watchService.errors.listen((error) {
      _showSnackBar('Watch error: $error', isError: true);
    });

    // Check initial connection state
    final isConnected = await _watchService.checkConnectionState();
    setState(() {
      _isWatchConnected = isConnected;
    });
  }

  void _cleanupWatchConnectivity() {
    _throwEventSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _errorSubscription?.cancel();
    
    if (_isWatchModeEnabled) {
      _watchService.endWatchSession();
    }
    
    _watchService.dispose();
  }

  Future<void> _enableWatchMode() async {
    if (_session == null) {
      _showSnackBar('No active session', isError: true);
      return;
    }

    if (!_isWatchConnected) {
      _showSnackBar('Apple Watch not connected', isError: true);
      return;
    }

    final watchState = WatchSessionHelper.fromPracticeSession(_session!);
    final success = await _watchService.startWatchSession(watchState);
    
    if (success) {
      setState(() {
        _isWatchModeEnabled = true;
      });
      
      _showSnackBar('Watch mode enabled! Use your Apple Watch to record throws.');
      
      final inputConfig = WatchSessionHelper.getInputConfigForPracticeSession(_session!);
      await _watchService.updateInputConfig(inputConfig);
    } else {
      _showSnackBar('Failed to enable watch mode', isError: true);
    }
  }

  Future<void> _disableWatchMode() async {
    final success = await _watchService.endWatchSession();
    
    if (success) {
      setState(() {
        _isWatchModeEnabled = false;
      });
      
      _showSnackBar('Watch mode disabled');
    }
  }

  Future<void> _handleWatchThrow(WatchThrowEvent event) async {
    debugPrint('🔵 Received throw from watch: ${event.isHit ? "HIT" : "MISS"}');
    
    await _onThrow(event.isHit);
    await _watchService.sendHapticFeedback(event.isHit ? 'success' : 'failure');
    await _syncSessionToWatch();
  }

  Future<void> _syncSessionToWatch() async {
    if (!_isWatchModeEnabled || _session == null) return;

    final watchState = WatchSessionHelper.fromPracticeSession(_session!);
    await _watchService.updateWatchSession(watchState);
    
    final inputConfig = WatchSessionHelper.getInputConfigForPracticeSession(_session!);
    await _watchService.updateInputConfig(inputConfig);
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // Existing Training Methods
  // ============================================================================

  Future<void> _checkForActiveSession() async {
    setState(() => _isLoading = true);
    final sessionManager = context.read<SessionManager>();
    final activeSession = sessionManager.activePracticeSession;

    if (activeSession != null && !activeSession.isComplete) {
      setState(() {
        _session = activeSession;
        _updateAccuracyHistory();
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startNewSession(int target) async {
    final sessionManager = context.read<SessionManager>();
    final newSession = await sessionManager.startPracticeSession(target: target);

    setState(() {
      _session = newSession;
      _currentStreak = 0;
      _bestStreak = 0;
      _accuracyHistory = [0.0];
    });
  }

  void _updateAccuracyHistory() {
    if (_session == null) return;
    _accuracyHistory = [];
    int cumulativeHits = 0;
    int cumulativeThrows = 0;
    
    for (var round in _session!.rounds) {
      for (var throw_ in round.batonThrows) {
        cumulativeThrows++;
        if (throw_.isHit) cumulativeHits++;
        _accuracyHistory.add(cumulativeThrows > 0 ? cumulativeHits / cumulativeThrows : 0.0);
      }
    }
  }

  Future<void> _onThrow(bool isHit) async {
    if (_session == null) return;

    _session!.addBatonResult(isHit);
    
    final sessionManager = context.read<SessionManager>();
    await sessionManager.updatePracticeSession(_session!);

    if (isHit) {
      _currentStreak++;
      if (_currentStreak > _bestStreak) {
        _bestStreak = _currentStreak;
      }
    } else {
      _currentStreak = 0;
    }

    _updateAccuracyHistory();
    setState(() {});

    // Sync to watch if watch mode is enabled
    if (_isWatchModeEnabled) {
      await _syncSessionToWatch();
    }

    if (_session!.totalBatons >= _session!.target && !_session!.isComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
      _showSessionCompleteDialog();
      return;
    }

    final currentRound = _session!.currentRound;
    if (currentRound != null && currentRound.totalBatonThrows >= 6 && !currentRound.isComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
      _showRoundCompleteDialog();
    }
  }

  void _showSessionCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total throws: ${_session!.totalBatons}'),
            Text('Accuracy: ${(_session!.accuracy * 100).toStringAsFixed(1)}%'),
            Text('Best streak: $_bestStreak'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _session = null);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRoundCompleteDialog() {
    final round = _session!.currentRound;
    if (round == null) return;

    final roundIndex = _session!.rounds.indexWhere((r) => r.id == round.id);
    if (roundIndex != -1) {
      _session!.rounds[roundIndex].isComplete = true;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Round ${round.roundNumber} Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Hits: ${round.hits}'),
            Text('Misses: ${round.misses}'),
            Text('Accuracy: ${(round.accuracy * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _session!.startNextRound();
              setState(() {});
            },
            child: const Text('Next Round'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_session == null) {
      return _TargetSelectionScreen(onTargetSelected: _startNewSession);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('8 Meter Practice'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          // Watch Mode Button
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: Icon(
                _isWatchModeEnabled
                    ? Icons.watch
                    : Icons.watch_outlined,
                color: _isWatchModeEnabled
                    ? Colors.green
                    : (_isWatchConnected ? Colors.white : Colors.grey),
              ),
              tooltip: _isWatchModeEnabled
                  ? 'Disable Watch Mode'
                  : (_isWatchConnected ? 'Enable Watch Mode' : 'Apple Watch Not Connected'),
              onPressed: _isWatchConnected
                  ? (_isWatchModeEnabled ? _disableWatchMode : _enableWatchMode)
                  : null,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Watch mode indicator banner
          if (_isWatchModeEnabled)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade700, Colors.blue.shade500],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.watch, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Watch Mode Active',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isWatchConnected ? Colors.greenAccent : Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ),
            ),
          
          // Session content
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Throws: ${_session!.totalBatons}/${_session!.target}'),
                  Text('Accuracy: ${(_session!.accuracy * 100).toStringAsFixed(1)}%'),
                  Text('Streak: $_currentStreak'),
                  const SizedBox(height: 32),
                  
                  // Throw buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: () => _onThrow(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          'HIT',
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () => _onThrow(false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                        ),
                        child: const Text(
                          'MISS',
                          style: TextStyle(fontSize: 24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Target selection screen
class _TargetSelectionScreen extends StatefulWidget {
  final Function(int) onTargetSelected;

  const _TargetSelectionScreen({required this.onTargetSelected});

  @override
  State<_TargetSelectionScreen> createState() => _TargetSelectionScreenState();
}

class _TargetSelectionScreenState extends State<_TargetSelectionScreen> {
  int _selectedTarget = 30;
  final List<int> _presetTargets = [30, 60, 90, 120];

  void _decreaseTarget() {
    if (_selectedTarget > 10) {
      setState(() {
        _selectedTarget -= 10;
      });
    }
  }

  void _increaseTarget() {
    setState(() {
      _selectedTarget += 10;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('8 Meter Practice'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Select Target',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _decreaseTarget,
                  icon: const Icon(Icons.remove),
                ),
                Text(
                  '$_selectedTarget',
                  style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: _increaseTarget,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: () => widget.onTargetSelected(_selectedTarget),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Start Practice',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
