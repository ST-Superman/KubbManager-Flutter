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

    // Check if round is complete (6 batons thrown)
    final currentRound = _session!.currentRound;
    if (currentRound != null && currentRound.totalBatonThrows >= 6 && !currentRound.isComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
      _showRoundCompleteDialog();
      return; // Don't check session completion yet
    }

    // Check if session is complete (target reached)
    if (_session!.totalBatons >= _session!.target && !_session!.isComplete) {
      await Future.delayed(const Duration(milliseconds: 300));
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
          // Pause Session
          IconButton(
            icon: const Icon(Icons.pause),
            tooltip: 'Pause Session',
            onPressed: () async {
              final shouldPause = await showDialog<bool>(
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

              if (shouldPause == true && mounted) {
                await context.read<SessionManager>().pausePracticeSession();
                widget.onExit();
              }
            },
          ),
          // End Session
          IconButton(
            icon: const Icon(Icons.stop),
            tooltip: 'End Session',
            onPressed: () async {
              final shouldEnd = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('End Session?'),
                  content: const Text(
                      'This will end the current session. Your progress will be saved.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      child: const Text('End Session'),
                    ),
                  ],
                ),
              );

              if (shouldEnd == true && mounted) {
                // Mark session as complete and save
                _session!.isComplete = true;
                await context.read<SessionManager>().updatePracticeSession(_session!);
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
            minHeight: 6,
          ),

          // Compact stats with streak
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CompactStat(
                      label: 'Progress',
                      value: '${_session.totalBatons}/${_session.target}',
                    ),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _CompactStat(
                      label: 'Hits',
                      value: '${_session.totalKubbs}',
                      color: Colors.green,
                    ),
                    Container(width: 1, height: 30, color: Colors.grey[300]),
                    _CompactStat(
                      label: 'Accuracy',
                      value: '${(_session.accuracy * 100).toStringAsFixed(1)}%',
                      color: Colors.blue,
                    ),
                  ],
                ),
                // Streak counter
                if (widget.currentStreak > 0) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
                        const SizedBox(width: 6),
                        Text(
                          'Streak: ${widget.currentStreak}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.bestStreak > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '(Best: ${widget.bestStreak})',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
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

          Divider(height: 1, color: Colors.grey[300]),

          // Main content area
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // Round info
                  if (currentRound != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Round ${currentRound.roundNumber}',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${currentRound.hits}/${currentRound.totalBatonThrows}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Kubbs visual
                    _KubbsVisual(
                      hitCount: currentRound.hits,
                      totalThrowsThisRound: currentRound.totalBatonThrows,
                    ),
                  ],

                  const Spacer(),

                  // Batons visual (moved above buttons for throwing perspective)
                  if (currentRound != null) ...[
                    _BatonsVisual(batonThrows: currentRound.batonThrows),
                    const SizedBox(height: 16),
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
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close, size: 40),
                              SizedBox(height: 4),
                              Text(
                                'Miss',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => widget.onThrow(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check, size: 40),
                              SizedBox(height: 4),
                              Text(
                                'Hit',
                                style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Live accuracy chart at bottom
                  if (widget.accuracyHistory.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Live Accuracy',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 100,
                            child: _AccuracyChart(accuracyHistory: widget.accuracyHistory),
                          ),
                        ],
                      ),
                    ),
                  ],
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

/// Compact stat widget for top bar
class _CompactStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _CompactStat({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
  final int totalThrowsThisRound;

  const _KubbsVisual({
    required this.hitCount, 
    required this.totalThrowsThisRound,
  });

  @override
  Widget build(BuildContext context) {
    final showKing = hitCount >= 5 && totalThrowsThisRound < 6;
    
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
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(5, (index) {
            final isHit = index < hitCount;
            // Random orientation for each kubb (consistent per index)
            final isBlueOnTop = (index % 2 == 0);
            
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                  transform: isHit 
                    ? Matrix4.rotationZ(0.5) // Fall down when hit
                    : Matrix4.identity(),
                  child: Stack(
                    children: [
                      // Kubb block with random orientation
                      _KubbBlock(isHit: isHit, isBlueOnTop: isBlueOnTop),
                      // Hit indicator overlay
                      if (isHit)
                        Positioned(
                          top: 2,
                          right: 2,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        
        // King kubb appears when 5 baseline kubbs are hit and baton remains
        if (showKing) ...[
          const SizedBox(height: 16),
          const Text(
            '⭐ KING KUBB ⭐',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 8),
          _KingKubbBlock(),
        ],
      ],
    );
  }
}

/// Custom kubb block widget using PNG assets
class _KubbBlock extends StatelessWidget {
  final bool isHit;
  final bool isBlueOnTop;

  const _KubbBlock({required this.isHit, required this.isBlueOnTop});

  @override
  Widget build(BuildContext context) {
    // Choose image based on hit status and orientation
    String imagePath;
    if (isHit) {
      // Use knocked down kubb images randomly
      imagePath = isBlueOnTop ? 'assets/images/sw_down_kubb1.png' : 'assets/images/sw_down_kubb2.png';
    } else {
      // Use standing kubb images randomly
      imagePath = isBlueOnTop ? 'assets/images/sw_kubb1.png' : 'assets/images/sw_kubb2.png';
    }

    return Container(
      width: 45,
      height: 70,
      child: Image.asset(
        imagePath,
        width: 45,
        height: 70,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to simple colored rectangle if image fails to load
          return Container(
            width: 45,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.black87, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 35,
                    color: isBlueOnTop ? Colors.blue.shade700 : Colors.yellow.shade600,
                  ),
                  Container(
                    width: double.infinity,
                    height: 35,
                    color: isBlueOnTop ? Colors.yellow.shade600 : Colors.blue.shade700,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Custom king kubb block widget using PNG asset
class _KingKubbBlock extends StatelessWidget {
  const _KingKubbBlock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 100,
      child: Image.asset(
        'assets/images/sw_king.png',
        width: 50,
        height: 100,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Fallback to simple dark grey rectangle if image fails to load
          return Container(
            width: 50,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              color: Colors.grey.shade800,
              border: Border.all(color: Colors.black87, width: 1),
            ),
            child: const Center(
              child: Icon(
                Icons.stars,
                color: Colors.amber,
                size: 24,
              ),
            ),
          );
        },
      ),
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
                child: hasThrow
                    ? Stack(
                        children: [
                          // Custom baton design
                          _BatonIcon(isHit: isHit),
                          // Hit/Miss indicator overlay
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: isHit ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Icon(
                                isHit ? Icons.check : Icons.close,
                                color: Colors.white,
                                size: 10,
                              ),
                            ),
                          ),
                          // King throw indicator
                          if (isKingThrow)
                            Positioned(
                              bottom: 2,
                              right: 2,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.amber,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.stars,
                                  color: Colors.white,
                                  size: 8,
                                ),
                              ),
                            ),
                        ],
                      )
                    : _BatonIcon(isHit: null),
              ),
            );
          }),
        ),
      ],
    );
  }
}

/// Custom baton icon widget using PNG asset
class _BatonIcon extends StatelessWidget {
  final bool? isHit; // null = empty, true = hit, false = miss

  const _BatonIcon({required this.isHit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 60,
      child: Image.asset(
              'assets/images/sw_baton.png',
              width: 30,
              height: 60,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Fallback to simple colored rectangle if image fails to load
                return Container(
                  width: 30,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: isHit == null ? Colors.grey.shade400 : Colors.black87, 
                      width: 1
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: isHit == null 
                      ? Container(color: Colors.grey.shade300)
                      : Column(
                          children: [
                            Container(
                              width: double.infinity,
                              height: 6,
                              color: Colors.yellow.shade600,
                            ),
                            Expanded(
                              child: Container(
                                width: double.infinity,
                                color: Colors.blue.shade600,
                              ),
                            ),
                            Container(
                              width: double.infinity,
                              height: 6,
                              color: Colors.yellow.shade600,
                            ),
                          ],
                        ),
                  ),
                );
              },
            ),
    );
  }
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
