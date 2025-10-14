import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../models/practice_session.dart';
import '../services/session_manager.dart';

/// Enhanced 8 Meter Practice with impressive Flutter features
/// Includes: Swipe gestures, animations, particle effects, haptics, combos
class EightMeterTrainingEnhanced extends StatefulWidget {
  const EightMeterTrainingEnhanced({super.key});

  @override
  State<EightMeterTrainingEnhanced> createState() =>
      _EightMeterTrainingEnhancedState();
}

class _EightMeterTrainingEnhancedState
    extends State<EightMeterTrainingEnhanced>
    with TickerProviderStateMixin {
  PracticeSession? _session;
  bool _isLoading = false;
  int _currentStreak = 0;
  int _bestStreak = 0;
  List<double> _accuracyHistory = [];

  // Animation controllers
  late AnimationController _batonThrowController;
  late AnimationController _explosionController;
  late AnimationController _streakController;
  
  bool _isThrowingAnimation = false;
  bool _lastThrowWasHit = false;

  @override
  void initState() {
    super.initState();
    _checkForActiveSession();
    
    // Initialize animation controllers
    _batonThrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _batonThrowController.dispose();
    _explosionController.dispose();
    _streakController.dispose();
    super.dispose();
  }

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
        _accuracyHistory.add(
          cumulativeThrows > 0 ? cumulativeHits / cumulativeThrows : 0.0,
        );
      }
    }
    
    if (_accuracyHistory.isEmpty) {
      _accuracyHistory = [0.0];
    }
  }

  Future<void> _recordThrow(bool isHit) async {
    if (_isThrowingAnimation) return;
    
    setState(() {
      _isThrowingAnimation = true;
      _lastThrowWasHit = isHit;
    });

    // Play baton throw animation
    await _batonThrowController.forward(from: 0.0);
    
    // Haptic feedback
    if (isHit) {
      HapticFeedback.mediumImpact();
      _explosionController.forward(from: 0.0);
      _currentStreak++;
      if (_currentStreak > _bestStreak) {
        _bestStreak = _currentStreak;
      }
      if (_currentStreak > 1) {
        _streakController.forward(from: 0.0);
      }
    } else {
      HapticFeedback.lightImpact();
      _currentStreak = 0;
    }

    // Update session
    setState(() {
      _session!.addBatonResult(isHit);
      _updateAccuracyHistory();
    });

    final sessionManager = context.read<SessionManager>();
    await sessionManager.updatePracticeSession(_session!);

    setState(() {
      _isThrowingAnimation = false;
    });

    // Check if round is complete
    if (_session!.currentRound?.isRoundComplete ?? false) {
      _showRoundCompleteDialog();
    }

    // Check if session is complete
    if (_session!.isTargetReached && !_session!.isComplete) {
      _showSessionCompleteDialog();
    }
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
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                'Round ${round.roundNumber} Complete!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              _buildStatRow('Hits', '${round.hits}', Colors.green),
              _buildStatRow('Misses', '${round.misses}', Colors.red),
              _buildStatRow(
                'Accuracy',
                '${(round.accuracy * 100).toStringAsFixed(1)}%',
                Colors.blue,
              ),
              if (round.hasBaselineClear) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.amber, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'Baseline Clear!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  _session!.startNextRound();
                  await context
                      .read<SessionManager>()
                      .updatePracticeSession(_session!);
                  if (mounted) {
                    Navigator.of(context).pop();
                    setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Next Round'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.celebration, color: Colors.amber, size: 80),
              const SizedBox(height: 16),
              Text(
                'Session Complete!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                '🎉 Congratulations! 🎉',
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 24),
              _buildStatRow('Total Batons', '${_session!.totalBatons}', null),
              _buildStatRow('Total Hits', '${_session!.totalKubbs}', Colors.green),
              _buildStatRow(
                'Accuracy',
                '${(_session!.accuracy * 100).toStringAsFixed(1)}%',
                Colors.blue,
              ),
              _buildStatRow('Best Streak', '$_bestStreak', Colors.orange),
              _buildStatRow('Rounds', '${_session!.completedRounds.length}', null),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () async {
                  await context.read<SessionManager>().completePracticeSession();
                  if (mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                ),
                child: const Text('Finish'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color? color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
      return _EnhancedTargetSelection(onTargetSelected: _startNewSession);
    }

    return _EnhancedPracticeScreen(
      session: _session!,
      onThrow: _recordThrow,
      isThrowingAnimation: _isThrowingAnimation,
      lastThrowWasHit: _lastThrowWasHit,
      batonAnimation: _batonThrowController,
      explosionAnimation: _explosionController,
      streakAnimation: _streakController,
      currentStreak: _currentStreak,
      bestStreak: _bestStreak,
      accuracyHistory: _accuracyHistory,
      onExit: () => Navigator.of(context).pop(),
    );
  }
}

/// Enhanced target selection with hero animation
class _EnhancedTargetSelection extends StatefulWidget {
  final Function(int) onTargetSelected;

  const _EnhancedTargetSelection({required this.onTargetSelected});

  @override
  State<_EnhancedTargetSelection> createState() =>
      _EnhancedTargetSelectionState();
}

class _EnhancedTargetSelectionState extends State<_EnhancedTargetSelection> {
  int _selectedTarget = 30;
  final List<int> _presetTargets = [30, 60, 90, 120];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('8 Meter Practice'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Hero(
              tag: 'practice_icon',
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.sports, size: 60, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Set Your Target',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            // Large target display with +/- controls
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _selectedTarget > 6
                          ? () => setState(() => _selectedTarget -= 6)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: 48,
                      color: Colors.blue,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$_selectedTarget',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _selectedTarget += 6),
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 48,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Adjust by 6', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            const Text('Quick Select',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: _presetTargets.map((target) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: OutlinedButton(
                      onPressed: () =>
                          setState(() => _selectedTarget = target),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: _selectedTarget == target
                              ? Colors.blue
                              : Colors.grey,
                          width: 2,
                        ),
                        backgroundColor: _selectedTarget == target
                            ? Colors.blue.withOpacity(0.1)
                            : null,
                      ),
                      child: Text(
                        '$target',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _selectedTarget == target
                              ? Colors.blue
                              : Colors.black,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => widget.onTargetSelected(_selectedTarget),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
                minimumSize: const Size(double.infinity, 60),
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

/// Enhanced practice screen with swipe gestures and animations
class _EnhancedPracticeScreen extends StatelessWidget {
  final PracticeSession session;
  final Function(bool) onThrow;
  final bool isThrowingAnimation;
  final bool lastThrowWasHit;
  final AnimationController batonAnimation;
  final AnimationController explosionAnimation;
  final AnimationController streakAnimation;
  final int currentStreak;
  final int bestStreak;
  final List<double> accuracyHistory;
  final VoidCallback onExit;

  const _EnhancedPracticeScreen({
    required this.session,
    required this.onThrow,
    required this.isThrowingAnimation,
    required this.lastThrowWasHit,
    required this.batonAnimation,
    required this.explosionAnimation,
    required this.streakAnimation,
    required this.currentStreak,
    required this.bestStreak,
    required this.accuracyHistory,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final currentRound = session.currentRound;

    return Scaffold(
      appBar: AppBar(
        title: const Text('8 Meter Practice'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.pause),
            onPressed: () async {
              final shouldExit = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Pause Session?'),
                  content: const Text('Resume later from history.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Pause'),
                    ),
                  ],
                ),
              );
              if (shouldExit == true && context.mounted) {
                await context.read<SessionManager>().pausePracticeSession();
                onExit();
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Progress bar
              LinearProgressIndicator(
                value: session.progressPercentage,
                minHeight: 8,
                backgroundColor: Colors.grey[200],
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      // Circular progress with stats
                      _CircularProgress(
                        progress: session.progressPercentage,
                        current: session.totalBatons,
                        target: session.target,
                        accuracy: session.accuracy,
                      ),
                      const SizedBox(height: 24),
                      
                      // Streak display
                      if (currentStreak > 1)
                        ScaleTransition(
                          scale: Tween<double>(begin: 1.0, end: 1.2).animate(
                            CurvedAnimation(
                              parent: streakAnimation,
                              curve: Curves.elasticOut,
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange, Colors.deepOrange],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.orange.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.local_fire_department,
                                    color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  '$currentStreak Hit Streak!',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      
                      // Round info
                      if (currentRound != null) ...[
                        Text(
                          'Round ${currentRound.roundNumber}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        
                        // Kubbs visual
                        _EnhancedKubbsVisual(
                          hitCount: currentRound.hits,
                          explosionAnimation: explosionAnimation,
                          showExplosion: isThrowingAnimation && lastThrowWasHit,
                        ),
                        const SizedBox(height: 24),
                        
                        // Batons visual
                        _EnhancedBatonsVisual(
                          batonThrows: currentRound.batonThrows,
                        ),
                        const SizedBox(height: 32),
                      ],
                      
                      // Swipe gesture area
                      _SwipeThrowArea(
                        onThrow: onThrow,
                        isAnimating: isThrowingAnimation,
                        batonAnimation: batonAnimation,
                        lastThrowWasHit: lastThrowWasHit,
                      ),
                      const SizedBox(height: 24),
                      
                      // Accuracy graph
                      if (accuracyHistory.length > 1)
                        _AccuracyGraph(data: accuracyHistory),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Circular progress indicator with stats
class _CircularProgress extends StatelessWidget {
  final double progress;
  final int current;
  final int target;
  final double accuracy;

  const _CircularProgress({
    required this.progress,
    required this.current,
    required this.target,
    required this.accuracy,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        children: [
          // Progress circle
          CircularProgressIndicator(
            value: progress,
            strokeWidth: 12,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              progress >= 1.0 ? Colors.green : Colors.blue,
            ),
          ),
          // Center text
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$current',
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'of $target',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${(accuracy * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Enhanced kubbs with explosion effects
class _EnhancedKubbsVisual extends StatelessWidget {
  final int hitCount;
  final AnimationController explosionAnimation;
  final bool showExplosion;

  const _EnhancedKubbsVisual({
    required this.hitCount,
    required this.explosionAnimation,
    required this.showExplosion,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Baseline Kubbs',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final isHit = index < hitCount;
            final justHit = showExplosion && index == hitCount - 1;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Explosion effect
                  if (justHit)
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.5, end: 2.0).animate(
                        CurvedAnimation(
                          parent: explosionAnimation,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                          explosionAnimation,
                        ),
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),
                  
                  // Kubb block
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 50,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isHit
                          ? Colors.grey.withOpacity(0.3)
                          : Colors.brown.shade700,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHit ? Colors.grey : Colors.brown.shade900,
                        width: 2,
                      ),
                      boxShadow: isHit
                          ? []
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Center(
                      child: isHit
                          ? const Icon(Icons.check_circle,
                              color: Colors.green, size: 32)
                          : Icon(Icons.square_rounded,
                              color: Colors.brown.shade400, size: 24),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Enhanced batons visual
class _EnhancedBatonsVisual extends StatelessWidget {
  final List<BatonThrow> batonThrows;

  const _EnhancedBatonsVisual({required this.batonThrows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'Batons This Round',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final hasThrow = index < batonThrows.length;
            final isHit = hasThrow ? batonThrows[index].isHit : false;
            final isKing =
                hasThrow && batonThrows[index].throwType == ThrowType.king;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.0),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 40,
                height: 50,
                decoration: BoxDecoration(
                  color: hasThrow
                      ? (isHit ? Colors.green : Colors.red)
                      : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: hasThrow
                        ? (isHit ? Colors.green.shade700 : Colors.red.shade700)
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                  boxShadow: hasThrow
                      ? [
                          BoxShadow(
                            color: (isHit ? Colors.green : Colors.red)
                                .withOpacity(0.4),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: hasThrow
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(isHit ? Icons.check : Icons.close,
                                color: Colors.white, size: 20),
                            if (isKing)
                              const Icon(Icons.stars,
                                  color: Colors.amber, size: 12),
                          ],
                        )
                      : Text('${index + 1}',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Swipe gesture area with animated baton
class _SwipeThrowArea extends StatefulWidget {
  final Function(bool) onThrow;
  final bool isAnimating;
  final AnimationController batonAnimation;
  final bool lastThrowWasHit;

  const _SwipeThrowArea({
    required this.onThrow,
    required this.isAnimating,
    required this.batonAnimation,
    required this.lastThrowWasHit,
  });

  @override
  State<_SwipeThrowArea> createState() => _SwipeThrowAreaState();
}

class _SwipeThrowAreaState extends State<_SwipeThrowArea> {
  Offset? _swipeStart;
  Offset? _swipeEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragStart: (details) {
        if (!widget.isAnimating) {
          _swipeStart = details.localPosition;
        }
      },
      onVerticalDragUpdate: (details) {
        if (!widget.isAnimating && _swipeStart != null) {
          setState(() {
            _swipeEnd = details.localPosition;
          });
        }
      },
      onVerticalDragEnd: (details) {
        if (!widget.isAnimating && _swipeStart != null && _swipeEnd != null) {
          final distance = _swipeStart!.dy - _swipeEnd!.dy;
          
          if (distance > 50) {
            // Upward swipe - throw!
            final velocity = details.velocity.pixelsPerSecond.dy.abs();
            final isHit = velocity > 500; // Fast swipe = hit!
            widget.onThrow(isHit);
          }
          
          setState(() {
            _swipeStart = null;
            _swipeEnd = null;
          });
        }
      },
      child: Container(
        height: 250,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.withOpacity(0.1),
              Colors.blue.withOpacity(0.3),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue, width: 3),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.arrow_upward,
                    size: 64,
                    color: Colors.blue.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Swipe Up to Throw!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Swipe fast for better accuracy',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Animated baton during throw
            if (widget.isAnimating)
              SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: const Offset(0, -1),
                ).animate(CurvedAnimation(
                  parent: widget.batonAnimation,
                  curve: Curves.easeInOut,
                )),
                child: RotationTransition(
                  turns: Tween<double>(begin: 0, end: 2).animate(
                    widget.batonAnimation,
                  ),
                  child: Center(
                    child: Container(
                      width: 60,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.brown.shade600,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Accuracy trend graph
class _AccuracyGraph extends StatelessWidget {
  final List<double> data;

  const _AccuracyGraph({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Accuracy Trend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 100,
              child: CustomPaint(
                painter: _GraphPainter(data: data),
                size: const Size(double.infinity, 100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for accuracy graph
class _GraphPainter extends CustomPainter {
  final List<double> data;

  _GraphPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path();
    final xStep = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final x = i * xStep;
      final y = size.height - (data[i] * size.height);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw fill
    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

