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
    });
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
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Icon(Icons.sports, size: 80, color: Colors.blue),
            const SizedBox(height: 24),
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
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),

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
            const SizedBox(height: 32),

            // Preset target buttons
            Text(
              'Quick Select',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
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
            
            const Spacer(),

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
  final VoidCallback onExit;

  const _PracticeSessionScreen({
    required this.session,
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
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _session.startNextRound();
              });
              context.read<SessionManager>().updatePracticeSession(_session);
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
                  // Stats card
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
                    const SizedBox(height: 32),
                  ],

                  // Hit/Miss buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _recordThrow(false),
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
                          onPressed: () => _recordThrow(true),
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
                  const SizedBox(height: 32),

                  // Recent throws
                  if (currentRound != null &&
                      currentRound.batonThrows.isNotEmpty) ...[
                    Text(
                      'Recent Throws',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: currentRound.batonThrows.reversed.map((throw_) {
                        return Chip(
                          label: Text(throw_.isHit ? 'Hit' : 'Miss'),
                          backgroundColor:
                              throw_.isHit ? Colors.green : Colors.red,
                          labelStyle: const TextStyle(color: Colors.white),
                        );
                      }).toList(),
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

