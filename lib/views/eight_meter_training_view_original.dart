import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/practice_session.dart';
import '../services/session_manager.dart';

/// 8 Meter Practice Training View
class EightMeterTrainingView extends StatefulWidget {
  const EightMeterTrainingView({super.key});

  @override
  State<EightMeterTrainingView> createState() =>
      _EightMeterTrainingViewState();
}

class _EightMeterTrainingViewState extends State<EightMeterTrainingView> {
  PracticeSession? _session;
  bool _isLoading = false;
  int _currentStreak = 0;
  int _bestStreak = 0;
  List<double> _accuracyHistory = [];

  @override
  void initState() {
    super.initState();
    _checkForActiveSession();
  }

  Future<void> _checkForActiveSession() async {
    setState(() => _isLoading = true);
    final sessionManager = context.read<SessionManager>();
    final activeSession = sessionManager.activePracticeSession;

    if (activeSession != null && !activeSession.isComplete) {
      // Resume existing session
      setState(() {
        _session = activeSession;
        _updateAccuracyHistory();
        _isLoading = false;
      });
    } else {
      // Show target selection
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
    } else {
      _currentStreak = 0;
    }

    // Update accuracy history
    _updateAccuracyHistory();

    setState(() {});

    // Check if round is complete
    final currentRound = _session!.currentRound;
    if (currentRound != null && currentRound.isComplete) {
      await Future.delayed(const Duration(milliseconds: 500));
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
      currentStreak: _currentStreak,
      bestStreak: _bestStreak,
      accuracyHistory: _accuracyHistory,
      onThrow: _onThrow,
      onExit: () {
        setState(() => _session = null);
        Navigator.of(context).pop();
      },
    );
  }
}

/// Target selection screen
class _TargetSelectionScreen extends StatefulWidget {
  final Function(int) onTargetSelected;

  const _TargetSelectionScreen({required this.onTargetSelected});

  @override
  State<_TargetSelectionScreen> createState() =>
      _TargetSelectionScreenState();
}

class _TargetSelectionScreenState extends State<_TargetSelectionScreen> {
  int _selectedTarget = 30;

  final List<int> _presetTargets = [30, 60, 90, 120];

  void _decreaseTarget() {
    setState(() {
      if (_selectedTarget > 6) {
        _selectedTarget -= 6;
      }
    });
  }

  void _increaseTarget() {
    setState(() {
      _selectedTarget += 6;
    });
  }

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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(Icons.sports, size: 60, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Set Your Target',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'How many batons would you like to throw?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Current target with +/- buttons
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minus button
                    IconButton(
                      onPressed: _selectedTarget > 6 ? _decreaseTarget : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 24),
                    
                    // Target number
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
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                      ),
                    ),
                    const SizedBox(width: 24),
                    
                    // Plus button
                    IconButton(
                      onPressed: _increaseTarget,
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 48,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Adjustment hint
            Text(
              'Adjust by 6',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Preset target buttons
            Text(
              'Quick Select',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _presetTargets.map((target) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: OutlinedButton(
                      onPressed: () => setState(() => _selectedTarget = target),
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
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 32),

            // Start button
            ElevatedButton(
              onPressed: () => widget.onTargetSelected(_selectedTarget),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(20),
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

/// Main practice session screen
class _PracticeSessionScreen extends StatefulWidget {
  final PracticeSession session;
  final int currentStreak;
  final int bestStreak;
  final List<double> accuracyHistory;
  final Function(bool) onThrow;
  final VoidCallback onExit;

  const _PracticeSessionScreen({
    required this.session,
    required this.currentStreak,
    required this.bestStreak,
    required this.accuracyHistory,
    required this.onThrow,
    required this.onExit,
  });

  @override
  State<_PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<_PracticeSessionScreen> {
  late PracticeSession _session;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
  }

  Future<void> _recordThrow(bool isHit) async {
    setState(() {
      _session.addBatonResult(isHit);
    });

    // Update in database
    final sessionManager = context.read<SessionManager>();
    await sessionManager.updatePracticeSession(_session);

    // Check if round is complete
    if (_session.currentRound?.isRoundComplete ?? false) {
      _showRoundCompleteDialog();
    }

    // Check if session is complete
    if (_session.isTargetReached && !_session.isComplete) {
      _showSessionCompleteDialog();
    }
  }

  void _showRoundCompleteDialog() {
    final round = _session.currentRound;
    if (round == null) return;

    // Mark the round as complete
    final roundIndex = _session.rounds.indexWhere((r) => r.id == round.id);
    if (roundIndex != -1) {
      _session.rounds[roundIndex].isComplete = true;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Round Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Round ${round.roundNumber}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _StatRow(
              label: 'Hits',
              value: '${round.hits}',
              color: Colors.green,
            ),
            _StatRow(
              label: 'Misses',
              value: '${round.misses}',
              color: Colors.red,
            ),
            _StatRow(
              label: 'Accuracy',
              value: '${(round.accuracy * 100).toStringAsFixed(1)}%',
              color: Colors.blue,
            ),
            if (round.hasBaselineClear)
              const Padding(
                padding: EdgeInsets.only(top: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 32),
                    SizedBox(width: 8),
                    Text(
                      'Baseline Clear!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // Start next round BEFORE closing dialog
              _session.startNextRound();
              await context.read<SessionManager>().updatePracticeSession(_session);
              
              if (mounted) {
                Navigator.of(context).pop();
                setState(() {
                  // Force rebuild with new round
                });
              }
            },
            child: const Text('Next Round'),
          ),
        ],
      ),
    );
  }

  void _showSessionCompleteDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Congratulations! 🎉',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _StatRow(
              label: 'Total Batons',
              value: '${_session.totalBatons}',
            ),
            _StatRow(
              label: 'Total Hits',
              value: '${_session.totalKubbs}',
            ),
            _StatRow(
              label: 'Accuracy',
              value: '${(_session.accuracy * 100).toStringAsFixed(1)}%',
            ),
            _StatRow(
              label: 'Rounds',
              value: '${_session.completedRounds.length}',
            ),
            _StatRow(
              label: 'Baseline Clears',
              value: '${_session.totalBaselineClears}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<SessionManager>().completePracticeSession();
              if (mounted) {
                Navigator.of(context).pop();
                widget.onExit();
              }
            },
            child: const Text('Finish'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentRound = _session.currentRound;

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
                  content: const Text(
                      'You can resume this session later from the history.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Pause'),
                    ),
                  ],
                ),
              );

              if (shouldExit == true && mounted) {
                await context.read<SessionManager>().pausePracticeSession();
                widget.onExit();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: _session.progressPercentage,
            backgroundColor: Colors.grey[200],
            minHeight: 8,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Stats card with streak
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatColumn(
                                label: 'Batons',
                                value: '${_session.totalBatons}/${_session.target}',
                              ),
                              _StatColumn(
                                label: 'Hits',
                                value: '${_session.totalKubbs}',
                                color: Colors.green,
                              ),
                              _StatColumn(
                                label: 'Accuracy',
                                value:
                                    '${(_session.accuracy * 100).toStringAsFixed(1)}%',
                                color: Colors.blue,
                              ),
                            ],
                          ),
                          // Streak counter
                          if (widget.currentStreak > 0) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Colors.red],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.white, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Streak: ${widget.currentStreak}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (widget.bestStreak > 0) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '(Best: ${widget.bestStreak})',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Current round info
                  if (currentRound != null) ...[
                    Text(
                      'Round ${currentRound.roundNumber}',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${currentRound.hits} hits / ${currentRound.totalBatonThrows} throws',
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Visual: Enhanced kubbs with king kubb
                    _EnhancedKubbsVisual(hitCount: currentRound.hits),
                    const SizedBox(height: 24),

                    // Visual: Batons thrown this round
                    _BatonsVisual(batonThrows: currentRound.batonThrows),
                    const SizedBox(height: 24),

                    // Live accuracy chart
                    if (widget.accuracyHistory.isNotEmpty)
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
                                child: _AccuracyChart(accuracyHistory: widget.accuracyHistory),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],

                  // Hit/Miss buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => widget.onThrow(false),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(32),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.close, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Miss',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => widget.onThrow(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(32),
                          ),
                          child: const Column(
                            children: [
                              Icon(Icons.check, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Hit',
                                style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stat row widget
class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatRow({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

/// Stat column widget
class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatColumn({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

/// Visual representation of 5 kubbs on baseline
class _KubbsVisual extends StatelessWidget {
  final int hitCount;

  const _KubbsVisual({required this.hitCount});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Baseline Kubbs',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final isHit = index < hitCount;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: AnimatedContainer(
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
                ),
                child: Center(
                  child: isHit
                      ? const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 32,
                        )
                      : Icon(
                          Icons.square_rounded,
                          color: Colors.brown.shade400,
                          size: 24,
                        ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Visual representation of batons thrown
class _BatonsVisual extends StatelessWidget {
  final List<BatonThrow> batonThrows;

  const _BatonsVisual({required this.batonThrows});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Batons This Round',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            final hasThrow = index < batonThrows.length;
            final isHit = hasThrow ? batonThrows[index].isHit : false;
            final isKingThrow =
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
                        ? (isHit
                            ? Colors.green.shade700
                            : Colors.red.shade700)
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Center(
                  child: hasThrow
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isHit ? Icons.check : Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                            if (isKingThrow)
                              const Icon(
                                Icons.stars,
                                color: Colors.amber,
                                size: 12,
                              ),
                          ],
                        )
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}


/// Enhanced kubbs visual with king kubb
class _EnhancedKubbsVisual extends StatelessWidget {
  final int hitCount;
  
  const _EnhancedKubbsVisual({required this.hitCount});

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
        
        // 5 baseline kubbs with realistic wooden appearance
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final isHit = index < hitCount;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
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
                          // Knocked over effect - draw diagonal lines
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
            );
          }),
        ),
        
        // King kubb appears after 5 hits
        if (hasKingThrow) ...[
          const SizedBox(height: 20),
          const Text(
            '⭐ KING KUBB ⭐',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 8),
          
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
      ],
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

/// Live accuracy chart with 50% target line
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

/// Custom painter for accuracy chart with 50% target line
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

    final targetPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

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

    // Draw 50% target line
    final targetY = maxY - (0.5 * maxY);
    canvas.drawLine(
      Offset(0, targetY),
      Offset(size.width, targetY),
      targetPaint,
    );

    // Draw target line label
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '50% Target',
        style: TextStyle(
          color: Colors.orange,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(8, targetY - 16));

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
