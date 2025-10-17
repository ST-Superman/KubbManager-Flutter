import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'package:provider/provider.dart';
import '../models/practice_session.dart';
import '../services/session_manager.dart';
import '../services/watch_connectivity_service.dart';
import '../services/watch_session_helper.dart';
import '../models/watch_session_state.dart';

/// Enhanced 8 Meter Practice with Apple Watch Support
/// Features: Flying baton, falling kubbs, particle effects, smooth transitions, watch mode
class EightMeterTrainingView extends StatefulWidget {
  const EightMeterTrainingView({super.key});

  @override
  State<EightMeterTrainingView> createState() => _EightMeterTrainingViewState();
}

class _EightMeterTrainingViewState extends State<EightMeterTrainingView>
    with TickerProviderStateMixin, WidgetsBindingObserver {
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

  // Animation controllers
  late AnimationController _batonController;
  late AnimationController _kubbController;
  late AnimationController _particleController;
  late AnimationController _streakController;

  // Animations
  late Animation<double> _batonAnimation;
  late Animation<double> _kubbAnimation;
  late Animation<double> _streakAnimation;

  // Animation state
  bool _isAnimating = false;
  bool _isHit = false;
  int _kubbsHit = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeWatchConnectivity();
    _initializeAnimations();
    _checkForActiveSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cleanupWatchConnectivity();
    _batonController.dispose();
    _kubbController.dispose();
    _particleController.dispose();
    _streakController.dispose();
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
  // Animation Methods
  // ============================================================================

  void _initializeAnimations() {
    _batonController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _kubbController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _streakController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _batonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _batonController,
      curve: Curves.easeInOut,
    ));

    _kubbAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _kubbController,
      curve: Curves.bounceOut,
    ));

    _streakAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _streakController,
      curve: Curves.elasticOut,
    ));
  }

  // ============================================================================
  // Session Methods
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
    if (_session == null || _isAnimating) return;

    _isAnimating = true;
    _isHit = isHit;
    _kubbsHit = isHit ? 1 : 0; // Simplified for now

    // Start animations
    _batonController.forward();
    if (isHit) {
      _kubbController.forward();
      _particleController.forward();
    }

    // Record the throw
    _session!.addBatonResult(isHit);
    
    // Update the session in the database
    final sessionManager = context.read<SessionManager>();
    await sessionManager.updatePracticeSession(_session!);

    // Update streak
    if (isHit) {
      _currentStreak++;
      if (_currentStreak > _bestStreak) {
        _bestStreak = _currentStreak;
        _streakController.forward();
      }
    } else {
      _currentStreak = 0;
    }

    // Update accuracy history
    _updateAccuracyHistory();
    setState(() {});

    // Sync to watch if watch mode is enabled
    if (_isWatchModeEnabled) {
      await _syncSessionToWatch();
    }

    // Reset animations after delay
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        _batonController.reset();
        _kubbController.reset();
        _particleController.reset();
        _streakController.reset();
        _isAnimating = false;
        setState(() {});
      }
    });

    // Check if session is complete
    if (_session!.totalBatons >= _session!.target && !_session!.isComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
      _showSessionCompleteDialog();
      return;
    }

    // Check if round is complete
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
            child: _SessionContent(
              session: _session!,
              currentStreak: _currentStreak,
              bestStreak: _bestStreak,
              accuracyHistory: _accuracyHistory,
              onThrow: _onThrow,
              isAnimating: _isAnimating,
              isHit: _isHit,
              kubbsHit: _kubbsHit,
              batonAnimation: _batonAnimation,
              kubbAnimation: _kubbAnimation,
              streakAnimation: _streakAnimation,
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

/// Session content with animations
class _SessionContent extends StatelessWidget {
  final PracticeSession session;
  final int currentStreak;
  final int bestStreak;
  final List<double> accuracyHistory;
  final Function(bool) onThrow;
  final bool isAnimating;
  final bool isHit;
  final int kubbsHit;
  final Animation<double> batonAnimation;
  final Animation<double> kubbAnimation;
  final Animation<double> streakAnimation;

  const _SessionContent({
    required this.session,
    required this.currentStreak,
    required this.bestStreak,
    required this.accuracyHistory,
    required this.onThrow,
    required this.isAnimating,
    required this.isHit,
    required this.kubbsHit,
    required this.batonAnimation,
    required this.kubbAnimation,
    required this.streakAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.blue.shade50,
                Colors.green.shade50,
              ],
            ),
          ),
        ),
        
        // Main content
        Column(
          children: [
            // Stats section
            _StatsSection(
              session: session,
              currentStreak: currentStreak,
              bestStreak: bestStreak,
              accuracyHistory: accuracyHistory,
              streakAnimation: streakAnimation,
            ),
            
            // Animation area
            Expanded(
              child: _AnimationArea(
                isAnimating: isAnimating,
                isHit: isHit,
                kubbsHit: kubbsHit,
                batonAnimation: batonAnimation,
                kubbAnimation: kubbAnimation,
              ),
            ),
            
            // Control buttons
            _ControlButtons(
              onThrow: onThrow,
              isAnimating: isAnimating,
            ),
          ],
        ),
      ],
    );
  }
}

/// Stats section
class _StatsSection extends StatelessWidget {
  final PracticeSession session;
  final int currentStreak;
  final int bestStreak;
  final List<double> accuracyHistory;
  final Animation<double> streakAnimation;

  const _StatsSection({
    required this.session,
    required this.currentStreak,
    required this.bestStreak,
    required this.accuracyHistory,
    required this.streakAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: session.totalBatons / session.target,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(
              session.totalBatons >= session.target ? Colors.green : Colors.blue,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatCard(
                title: 'Throws',
                value: '${session.totalBatons}/${session.target}',
                color: Colors.blue,
              ),
              _StatCard(
                title: 'Accuracy',
                value: '${(session.accuracy * 100).toStringAsFixed(1)}%',
                color: Colors.green,
              ),
              AnimatedBuilder(
                animation: streakAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (streakAnimation.value * 0.2),
                    child: _StatCard(
                      title: 'Streak',
                      value: '$currentStreak',
                      color: Colors.orange,
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stat card
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              color: color.shade800,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animation area
class _AnimationArea extends StatelessWidget {
  final bool isAnimating;
  final bool isHit;
  final int kubbsHit;
  final Animation<double> batonAnimation;
  final Animation<double> kubbAnimation;

  const _AnimationArea({
    required this.isAnimating,
    required this.isHit,
    required this.kubbsHit,
    required this.batonAnimation,
    required this.kubbAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([batonAnimation, kubbAnimation]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Kubb target
                _KubbTarget(
                  isHit: isHit && isAnimating,
                  animation: kubbAnimation,
                ),
                
                // Flying baton
                if (isAnimating)
                  _FlyingBaton(
                    animation: batonAnimation,
                    isHit: isHit,
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Kubb target
class _KubbTarget extends StatelessWidget {
  final bool isHit;
  final Animation<double> animation;

  const _KubbTarget({
    required this.isHit,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, isHit ? animation.value * 50 : 0),
          child: Transform.rotate(
            angle: isHit ? animation.value * 0.5 : 0,
            child: Container(
              width: 80,
              height: 100,
              decoration: BoxDecoration(
                color: isHit ? Colors.red.shade300 : Colors.brown.shade400,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'KUBB',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Flying baton
class _FlyingBaton extends StatelessWidget {
  final Animation<double> animation;
  final bool isHit;

  const _FlyingBaton({
    required this.animation,
    required this.isHit,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            (animation.value - 0.5) * 200,
            -animation.value * 100,
          ),
          child: Transform.rotate(
            angle: animation.value * 2 * math.pi,
            child: Container(
              width: 60,
              height: 8,
              decoration: BoxDecoration(
                color: isHit ? Colors.green : Colors.brown,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Control buttons
class _ControlButtons extends StatelessWidget {
  final Function(bool) onThrow;
  final bool isAnimating;

  const _ControlButtons({
    required this.onThrow,
    required this.isAnimating,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: isAnimating ? null : () => onThrow(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'HIT',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: isAnimating ? null : () => onThrow(false),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'MISS',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
