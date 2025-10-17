import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import '../models/practice_session.dart';
import '../services/session_manager.dart';

/// Enhanced 8 Meter Practice with SMOOTH Flutter animations
/// Features: Flying baton, falling kubbs, particle effects, smooth transitions
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

  // Animation controllers for smooth animations
  late AnimationController _batonFlightController;
  late AnimationController _kubbFallController;
  late AnimationController _explosionController;
  late AnimationController _streakController;
  late AnimationController _kingAppearController;
  
  // Animation states
  bool _isBatonFlying = false;
  bool _isKubbFalling = false;
  int _targetKubbIndex = -1;
  bool _showExplosion = false;
  bool _lastThrowWasHit = false;

  @override
  void initState() {
    super.initState();
    _checkForActiveSession();
    
    // Initialize smooth animation controllers
    _batonFlightController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _kubbFallController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _explosionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _streakController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    _kingAppearController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _batonFlightController.dispose();
    _kubbFallController.dispose();
    _explosionController.dispose();
    _streakController.dispose();
    _kingAppearController.dispose();
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
        _accuracyHistory.add(cumulativeThrows > 0 ? cumulativeHits / cumulativeThrows : 0.0);
      }
    }
  }

  Future<void> _onThrow(bool isHit) async {
    if (_session == null || _isBatonFlying || _isKubbFalling) return;

    setState(() {
      _lastThrowWasHit = isHit;
      _isBatonFlying = true;
      _targetKubbIndex = isHit ? _session!.currentRound!.hits : -1;
    });

    // Haptic feedback
    if (isHit) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }

    // Start baton flight animation
    await _batonFlightController.forward();

    // If hit, start kubb falling animation
    if (isHit) {
      setState(() => _isKubbFalling = true);
      await _kubbFallController.forward();
      
      // Show explosion
      setState(() => _showExplosion = true);
      await _explosionController.forward();
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
      }
      _streakController.forward().then((_) => _streakController.reverse());
    } else {
      _currentStreak = 0;
    }

    // Update accuracy history
    _updateAccuracyHistory();

    // Reset animation states
    setState(() {
      _isBatonFlying = false;
      _isKubbFalling = false;
      _showExplosion = false;
      _targetKubbIndex = -1;
    });

    // Reset controllers for next throw
    _batonFlightController.reset();
    _kubbFallController.reset();
    _explosionController.reset();

    // Check if round is complete
    final currentRound = _session!.currentRound;
    if (currentRound != null && currentRound.isComplete) {
      await Future.delayed(const Duration(milliseconds: 800));
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

    // Check for perfect round (6 for 6!)
    final isPerfectRound = round.totalBatonThrows == 6 && round.hits == 6;

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
              Icon(
                isPerfectRound ? Icons.celebration : Icons.check_circle,
                color: isPerfectRound ? Colors.amber : Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              
              // Perfect round celebration
              if (isPerfectRound) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.amber, Colors.orange],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Text(
                    '🏆 PERFECT 6 FOR 6! 🏆',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
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
              if (round.hasBaselineClear && !isPerfectRound) ...[
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
                  await context.read<SessionManager>().updatePracticeSession(_session!);
                  setState(() {
                    _currentStreak = 0;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Next Round'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSessionCompleteDialog() {
    final totalThrows = _session!.totalBatons;
    final totalHits = _session!.totalKubbs;
    final overallAccuracy = totalThrows > 0 ? totalHits / totalThrows : 0.0;

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
              const Icon(Icons.flag, color: Colors.green, size: 64),
              const SizedBox(height: 16),
              Text(
                'Session Complete!',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              _buildStatRow('Total Throws', '$totalThrows', Colors.blue),
              _buildStatRow('Total Hits', '$totalHits', Colors.green),
              _buildStatRow(
                'Overall Accuracy',
                '${(overallAccuracy * 100).toStringAsFixed(1)}%',
                Colors.orange,
              ),
              _buildStatRow('Best Streak', '$_bestStreak', Colors.purple),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await context.read<SessionManager>().completePracticeSession();
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Finish'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await context.read<SessionManager>().completePracticeSession();
                        Navigator.of(context).pop();
                        await _startNewSession(_session!.target);
                      },
                      child: const Text('New Session'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
              ),
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
      return _TargetSelectionScreen(onTargetSelected: _startNewSession);
    }

    return _PracticeSessionScreen(
      session: _session!,
      onThrow: _onThrow,
      isBatonFlying: _isBatonFlying,
      isKubbFalling: _isKubbFalling,
      targetKubbIndex: _targetKubbIndex,
      showExplosion: _showExplosion,
      currentStreak: _currentStreak,
      bestStreak: _bestStreak,
      accuracyHistory: _accuracyHistory,
      batonFlightController: _batonFlightController,
      kubbFallController: _kubbFallController,
      explosionController: _explosionController,
      streakController: _streakController,
      kingAppearController: _kingAppearController,
    );
  }
}

/// Target selection screen
class _TargetSelectionScreen extends StatelessWidget {
  final Function(int) onTargetSelected;

  const _TargetSelectionScreen({required this.onTargetSelected});

  @override
  Widget build(BuildContext context) {
    final presetTargets = [30, 60, 90, 120];

    return Scaffold(
      appBar: AppBar(
        title: const Text('8 Meter Practice - Enhanced'),
        backgroundColor: Colors.blue.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 64,
                      color: Colors.amber.shade600,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Enhanced Mode',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '🔥 Flying batons, falling kubbs, particle effects!',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Choose Target Batons',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ...presetTargets.map((target) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ElevatedButton(
                    onPressed: () => onTargetSelected(target),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(20),
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      '$target Batons',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

/// Main practice session screen with animations
class _PracticeSessionScreen extends StatelessWidget {
  final PracticeSession session;
  final Function(bool) onThrow;
  final bool isBatonFlying;
  final bool isKubbFalling;
  final int targetKubbIndex;
  final bool showExplosion;
  final int currentStreak;
  final int bestStreak;
  final List<double> accuracyHistory;
  final AnimationController batonFlightController;
  final AnimationController kubbFallController;
  final AnimationController explosionController;
  final AnimationController streakController;
  final AnimationController kingAppearController;

  const _PracticeSessionScreen({
    required this.session,
    required this.onThrow,
    required this.isBatonFlying,
    required this.isKubbFalling,
    required this.targetKubbIndex,
    required this.showExplosion,
    required this.currentStreak,
    required this.bestStreak,
    required this.accuracyHistory,
    required this.batonFlightController,
    required this.kubbFallController,
    required this.explosionController,
    required this.streakController,
    required this.kingAppearController,
  });

  @override
  Widget build(BuildContext context) {
    final currentRound = session.currentRound;
    if (currentRound == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('8 Meter Practice - Enhanced'),
        backgroundColor: Colors.blue.shade50,
        actions: [
          if (currentStreak > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Colors.red],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Session progress
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Round ${currentRound.roundNumber}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${session.totalKubbs}/${session.target}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: session.totalKubbs / session.target,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Animated kubbs with flying baton
            _AnimatedKubbsVisual(
              hitCount: currentRound.hits,
              isBatonFlying: isBatonFlying,
              isKubbFalling: isKubbFalling,
              targetKubbIndex: targetKubbIndex,
              showExplosion: showExplosion,
              batonFlightController: batonFlightController,
              kubbFallController: kubbFallController,
              explosionController: explosionController,
              kingAppearController: kingAppearController,
            ),
            const SizedBox(height: 32),

            // Hit/Miss buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isBatonFlying || isKubbFalling
                        ? null
                        : () => onThrow(false), // Miss button
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(32),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.close, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Miss',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isBatonFlying || isKubbFalling
                        ? null
                        : () => onThrow(true), // Hit button
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(32),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check, size: 48),
                        SizedBox(height: 8),
                        Text(
                          'Hit',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Live accuracy chart
            if (accuracyHistory.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Live Accuracy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: _AccuracyChart(accuracyHistory: accuracyHistory),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Animated kubbs with flying baton and falling effects
class _AnimatedKubbsVisual extends StatelessWidget {
  final int hitCount;
  final bool isBatonFlying;
  final bool isKubbFalling;
  final int targetKubbIndex;
  final bool showExplosion;
  final AnimationController batonFlightController;
  final AnimationController kubbFallController;
  final AnimationController explosionController;
  final AnimationController kingAppearController;

  const _AnimatedKubbsVisual({
    required this.hitCount,
    required this.isBatonFlying,
    required this.isKubbFalling,
    required this.targetKubbIndex,
    required this.showExplosion,
    required this.batonFlightController,
    required this.kubbFallController,
    required this.explosionController,
    required this.kingAppearController,
  });

  @override
  Widget build(BuildContext context) {
    final hasKingThrow = hitCount >= 5;
    
    return Column(
      children: [
        const Text(
          'Baseline Kubbs',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        
        // Flying baton
        if (isBatonFlying)
          _FlyingBaton(
            animation: batonFlightController,
            targetIndex: targetKubbIndex,
          ),
        
        const SizedBox(height: 20),
        
        // 5 baseline kubbs with smooth animations
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final isHit = index < hitCount;
            final isTarget = index == targetKubbIndex;
            final justHit = showExplosion && index == targetKubbIndex;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Explosion effect
                  if (justHit)
                    ScaleTransition(
                      scale: Tween<double>(begin: 0.5, end: 2.5).animate(
                        CurvedAnimation(
                          parent: explosionController,
                          curve: Curves.easeOut,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                          explosionController,
                        ),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.orange.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ),
                  
                  // Kubb with smooth falling animation
                  AnimatedBuilder(
                    animation: kubbFallController,
                    builder: (context, child) {
                      final fallRotation = isTarget && isKubbFalling
                          ? kubbFallController.value * math.pi / 2
                          : 0.0;
                      final fallOffset = isTarget && isKubbFalling
                          ? kubbFallController.value * 20
                          : 0.0;
                      
                      return Transform.translate(
                        offset: Offset(0, fallOffset),
                        child: Transform.rotate(
                          angle: fallRotation,
                          child: Container(
                            width: 44,
                            height: 70,
                            decoration: BoxDecoration(
                              // Gradient to look like wood
                              gradient: isHit
                                  ? LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.grey.shade400,
                                        Colors.grey.shade600,
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.brown.shade400,
                                        Colors.brown.shade700,
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isHit
                                    ? Colors.grey.shade700
                                    : Colors.brown.shade900,
                                width: 2,
                              ),
                              boxShadow: isHit
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.4),
                                        blurRadius: 6,
                                        offset: const Offset(2, 3),
                                      ),
                                    ],
                            ),
                            child: isHit
                                ? Stack(
                                    children: [
                                      // Knocked over effect
                                      CustomPaint(
                                        painter: _KnockedKubbPainter(),
                                        size: const Size(44, 70),
                                      ),
                                      Center(
                                        child: Icon(
                                          Icons.close,
                                          color: Colors.grey.shade800,
                                          size: 30,
                                        ),
                                      ),
                                    ],
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: Colors.brown.shade900,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          width: 30,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: Colors.brown.shade900,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          width: 30,
                                          height: 3,
                                          decoration: BoxDecoration(
                                            color: Colors.brown.shade900,
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          }),
        ),
        
        // King kubb appears after 5 hits
        if (hasKingThrow) ...[
          const SizedBox(height: 20),
          AnimatedBuilder(
            animation: kingAppearController,
            builder: (context, child) {
              return Transform.scale(
                scale: 0.5 + (kingAppearController.value * 0.5),
                child: Opacity(
                  opacity: kingAppearController.value,
                  child: Column(
                    children: [
                      const Text(
                        '⭐ KING KUBB ⭐',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.amber,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          // Explosion for king
                          if (showExplosion && hitCount == 6)
                            ScaleTransition(
                              scale: Tween<double>(begin: 0.5, end: 3.0).animate(
                                CurvedAnimation(
                                  parent: explosionController,
                                  curve: Curves.easeOut,
                                ),
                              ),
                              child: FadeTransition(
                                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                                  explosionController,
                                ),
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.amber.withOpacity(0.8),
                                  ),
                                ),
                              ),
                            ),
                          
                          // King kubb - taller and decorated
                          Container(
                            width: 52,
                            height: 90,
                            decoration: BoxDecoration(
                              gradient: hitCount >= 6
                                  ? LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.grey.shade400,
                                        Colors.grey.shade600,
                                      ],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.amber.shade300,
                                        Colors.amber.shade700,
                                      ],
                                    ),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: hitCount >= 6
                                    ? Colors.grey.shade700
                                    : Colors.amber.shade900,
                                width: 3,
                              ),
                              boxShadow: hitCount >= 6
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.amber.withOpacity(0.5),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                            ),
                            child: hitCount >= 6
                                ? Center(
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.grey.shade800,
                                      size: 40,
                                    ),
                                  )
                                : Stack(
                                    children: [
                                      // Crown on top
                                      Positioned(
                                        top: 8,
                                        left: 0,
                                        right: 0,
                                        child: Icon(
                                          Icons.emoji_events,
                                          color: Colors.amber.shade900,
                                          size: 28,
                                        ),
                                      ),
                                      // Decorative lines
                                      Center(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(
                                            4,
                                            (i) => Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 3),
                                              child: Container(
                                                width: 36,
                                                height: 3,
                                                decoration: BoxDecoration(
                                                  color: Colors.amber.shade900,
                                                  borderRadius: BorderRadius.circular(2),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Flying baton animation
class _FlyingBaton extends StatelessWidget {
  final Animation<double> animation;
  final int targetIndex;

  const _FlyingBaton({
    required this.animation,
    required this.targetIndex,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // Calculate flight path
        final progress = animation.value;
        final startX = MediaQuery.of(context).size.width * 0.8;
        final startY = 100.0;
        
        // Target position (kubb positions)
        final targetX = MediaQuery.of(context).size.width * 0.5 + (targetIndex - 2) * 56.0;
        final targetY = 250.0;
        
        // Parabolic flight path
        final currentX = startX + (targetX - startX) * progress;
        final currentY = startY + (targetY - startY) * progress - 
                        (progress * (1 - progress)) * 100; // Arc
        
        // Rotation during flight
        final rotation = progress * math.pi * 4; // Multiple spins
        
        return Positioned(
          left: currentX - 20,
          top: currentY - 10,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: 40,
              height: 8,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.brown.shade600, Colors.brown.shade800],
                ),
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

/// Custom painter for knocked down kubb effect
class _KnockedKubbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw diagonal lines to show it's knocked over
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.3),
      Offset(size.width * 0.7, size.height * 0.7),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Simple accuracy chart
class _AccuracyChart extends StatelessWidget {
  final List<double> accuracyHistory;

  const _AccuracyChart({required this.accuracyHistory});

  @override
  Widget build(BuildContext context) {
    if (accuracyHistory.isEmpty) {
      return const Center(
        child: Text('Start throwing to see your accuracy!'),
      );
    }

    return CustomPaint(
      size: const Size(double.infinity, 200),
      painter: _AccuracyChartPainter(accuracyHistory: accuracyHistory),
    );
  }
}

/// Custom painter for accuracy chart
class _AccuracyChartPainter extends CustomPainter {
  final List<double> accuracyHistory;

  _AccuracyChartPainter({required this.accuracyHistory});

  @override
  void paint(Canvas canvas, Size size) {
    if (accuracyHistory.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    final stepX = size.width / (accuracyHistory.length - 1);
    final maxY = size.height - 40;

    // Start the path
    path.moveTo(0, maxY - (accuracyHistory[0] * maxY));
    fillPath.moveTo(0, maxY);
    fillPath.lineTo(0, maxY - (accuracyHistory[0] * maxY));

    for (int i = 1; i < accuracyHistory.length; i++) {
      final x = i * stepX;
      final y = maxY - (accuracyHistory[i] * maxY);
      
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // Close the fill path
    fillPath.lineTo(size.width, maxY);
    fillPath.close();

    // Draw filled area first
    canvas.drawPath(fillPath, fillPaint);
    
    // Draw line
    canvas.drawPath(path, paint);

    // Draw data points
    final pointPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    for (int i = 0; i < accuracyHistory.length; i++) {
      final x = i * stepX;
      final y = maxY - (accuracyHistory[i] * maxY);
      
      canvas.drawCircle(Offset(x, y), 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}