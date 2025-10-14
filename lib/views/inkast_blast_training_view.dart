import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inkast_blast_session.dart';
import '../services/session_manager.dart';

/// Main view for Inkast Blast training sessions
class InkastBlastTrainingView extends StatefulWidget {
  final GamePhase gamePhase;

  const InkastBlastTrainingView({
    super.key,
    required this.gamePhase,
  });

  @override
  State<InkastBlastTrainingView> createState() =>
      _InkastBlastTrainingViewState();
}

class _InkastBlastTrainingViewState extends State<InkastBlastTrainingView> {
  final Random _random = Random();
  InkastBlastSession? _session;
  InkastBlastRound? _currentRound;
  RoundPhase _roundPhase = RoundPhase.inkast;
  Set<int> _knockedDownKubbs = {};

  @override
  void initState() {
    super.initState();
    _startNewSession();
  }

  Future<void> _startNewSession() async {
    final sessionManager = Provider.of<SessionManager>(context, listen: false);
    final session =
        await sessionManager.startInkastBlastSession(gamePhase: widget.gamePhase);

    setState(() {
      _session = session;
      _generateNewRound();
    });
  }

  void _generateNewRound() {
    if (_session == null) return;

    // Generate random kubb count within the game phase range
    final minKubbs = widget.gamePhase.minKubbs;
    final maxKubbs = widget.gamePhase.maxKubbs;
    final kubbCount = minKubbs + _random.nextInt(maxKubbs - minKubbs + 1);
    final roundNumber = _session!.rounds.length + 1;

    // Debug output to verify random generation
    debugPrint('🎲 Inkast Blast: Generated $kubbCount kubbs (range: $minKubbs-$maxKubbs) for round $roundNumber');

    setState(() {
      _currentRound =
          InkastBlastRound(roundNumber: roundNumber, inkastKubbs: kubbCount);
      _roundPhase = RoundPhase.inkast;
      _knockedDownKubbs = {};
    });
  }

  Future<void> _recordInkastResults({
    required int firstAttemptOut,
    required int secondAttemptOut,
    required int neighbors,
  }) async {
    setState(() {
      _currentRound?.recordInkastResults(
        firstAttemptOut: firstAttemptOut,
        secondAttemptOut: secondAttemptOut,
        neighbors: neighbors,
      );
      _roundPhase = RoundPhase.blasting;
    });
  }

  Future<void> _addBatonThrow({required bool isHit, int kubbsHit = 0}) async {
    if (_currentRound == null) return;

    setState(() {
      _currentRound!.addBatonThrow(isHit: isHit, kubbsHit: kubbsHit);

      if (isHit) {
        // Update knocked down kubbs for visual tracking
        for (int i = 0; i < kubbsHit; i++) {
          _knockedDownKubbs.add(_knockedDownKubbs.length);
        }
      }

      // Check if round is complete
      if (_currentRound!.isComplete) {
        _completeCurrentRound();
      }
    });
  }

  Future<void> _completeCurrentRound() async {
    if (_session == null || _currentRound == null) return;

    final sessionManager = Provider.of<SessionManager>(context, listen: false);

    setState(() {
      _session!.addRound(_currentRound!);
      _roundPhase = RoundPhase.roundComplete;
    });

    await sessionManager.updateInkastBlastSession(_session!);
  }

  Future<void> _startNextRound() async {
    _generateNewRound();
  }

  Future<void> _endSession() async {
    if (_session == null) return;

    final sessionManager = Provider.of<SessionManager>(context, listen: false);
    await sessionManager.completeInkastBlastSession();

    if (mounted) {
      _showSessionSummary();
    }
  }

  void _showSessionSummary() {
    if (_session == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Total Rounds: ${_session!.totalRounds}'),
            Text('Total Inkast Kubbs: ${_session!.totalInkastKubbs}'),
            Text('Total Batons Used: ${_session!.totalBatonsUsed}'),
            Text(
                'Average Kubbs/Baton: ${_session!.averageKubbsPerBaton.toStringAsFixed(2)}'),
            Text('Penalty Rate: ${(_session!.penaltyRate * 100).toStringAsFixed(1)}%'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Go back to landing page
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inkast & Blast'),
        backgroundColor: Colors.deepOrange.shade700,
        actions: [
          if (_session != null)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'end') {
                  _endSession();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'end',
                  child: Text('End Session'),
                ),
              ],
            ),
        ],
      ),
      body: _session == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSessionHeader(),
                  const SizedBox(height: 20),
                  if (_currentRound != null) _buildCurrentRoundInfo(),
                  const SizedBox(height: 20),
                  _buildRoundPhaseContent(),
                ],
              ),
            ),
    );
  }

  Widget _buildSessionHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Round ${_session!.rounds.length + 1}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  widget.gamePhase.displayName,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Rounds', _session!.totalRounds.toString()),
                _buildStatItem('Batons', _session!.totalBatonsUsed.toString()),
                _buildStatItem(
                  'Avg K/B',
                  _session!.averageKubbsPerBaton.toStringAsFixed(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ],
    );
  }

  Widget _buildCurrentRoundInfo() {
    if (_currentRound == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Inkast ${_currentRound!.inkastKubbs} kubbs',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (_currentRound!.isComplete)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Complete',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (_currentRound!.isComplete) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Target: ${_currentRound!.targetBatons} batons',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Used: ${_currentRound!.batonsUsed} batons',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _currentRound!.performanceVsTarget > 0
                    ? '+${_currentRound!.performanceVsTarget} (under target!)'
                    : _currentRound!.performanceVsTarget < 0
                        ? '${_currentRound!.performanceVsTarget} (over target)'
                        : 'Exactly on target!',
                style: TextStyle(
                  color: _currentRound!.performanceVsTarget > 0
                      ? Colors.green
                      : _currentRound!.performanceVsTarget < 0
                          ? Colors.red
                          : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoundPhaseContent() {
    switch (_roundPhase) {
      case RoundPhase.inkast:
        return _buildInkastPhase();
      case RoundPhase.blasting:
        return _buildBlastingPhase();
      case RoundPhase.roundComplete:
        return _buildRoundCompletePhase();
    }
  }

  Widget _buildInkastPhase() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Inkast Phase',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Throw ${_currentRound!.inkastKubbs} kubbs past the midline',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showInkastRecordingDialog(),
              icon: const Icon(Icons.edit),
              label: const Text('Record Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                textStyle: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlastingPhase() {
    if (_currentRound == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Blasting Phase',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Text(
              'Stand up the kubbs and clear them',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Target: ${_currentRound!.targetBatons} batons',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kubbs in bounds: ${_currentRound!.totalKubbsInBounds}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Batons used: ${_currentRound!.batonsUsed}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              'Kubbs knocked down: ${_currentRound!.kubbsClearedFirstThrow}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _addBatonThrow(isHit: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.close, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'MISS',
                          style: TextStyle(
                            fontSize: 18,
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
                    onPressed: () => _showHitRecordingDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check, size: 40),
                        SizedBox(height: 8),
                        Text(
                          'HIT',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundCompletePhase() {
    if (_currentRound == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Round Complete!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
            ),
            const SizedBox(height: 16),
            Text('Used ${_currentRound!.batonsUsed} batons'),
            Text('Target was ${_currentRound!.targetBatons} batons'),
            const SizedBox(height: 8),
            Text(
              _currentRound!.performanceVsTarget > 0
                  ? '+${_currentRound!.performanceVsTarget} under target! 🎉'
                  : _currentRound!.performanceVsTarget < 0
                      ? '${_currentRound!.performanceVsTarget} over target'
                      : 'Exactly on target! 🎯',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _currentRound!.performanceVsTarget > 0
                    ? Colors.green
                    : _currentRound!.performanceVsTarget < 0
                        ? Colors.red
                        : Colors.blue,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _startNextRound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'Next Round',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _endSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      'End Session',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInkastRecordingDialog() {
    showDialog(
      context: context,
      builder: (context) => _InkastRecordingDialog(
        totalKubbs: _currentRound!.inkastKubbs,
        onComplete: (firstAttemptOut, secondAttemptOut, neighbors) {
          _recordInkastResults(
            firstAttemptOut: firstAttemptOut,
            secondAttemptOut: secondAttemptOut,
            neighbors: neighbors,
          );
          Navigator.of(context).pop();
        },
      ),
    );
  }

  void _showHitRecordingDialog() {
    if (_currentRound == null) return;
    
    // Calculate remaining kubbs
    final remainingKubbs = _currentRound!.totalKubbsInBounds - _currentRound!.kubbsClearedFirstThrow;
    
    showDialog(
      context: context,
      builder: (context) => _HitRecordingDialog(
        remainingKubbs: remainingKubbs,
        onConfirm: (kubbsHit) {
          _addBatonThrow(isHit: true, kubbsHit: kubbsHit);
          Navigator.of(context).pop();
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      ),
    );
  }
}

// ============================================================================
// Round Phase Enum
// ============================================================================

enum RoundPhase {
  inkast,
  blasting,
  roundComplete,
}

// ============================================================================
// Inkast Recording Dialog
// ============================================================================

class _InkastRecordingDialog extends StatefulWidget {
  final int totalKubbs;
  final Function(int firstAttemptOut, int secondAttemptOut, int neighbors)
      onComplete;

  const _InkastRecordingDialog({
    required this.totalKubbs,
    required this.onComplete,
  });

  @override
  State<_InkastRecordingDialog> createState() => _InkastRecordingDialogState();
}

class _InkastRecordingDialogState extends State<_InkastRecordingDialog> {
  int _step = 1; // 1 = first attempt, 2 = second attempt, 3 = neighbors
  int _firstAttemptOut = 0;
  int _secondAttemptOut = 0;
  int _neighborCount = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_getStepTitle()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _getStepDescription(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Text(
            _getCurrentValue().toString(),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _canDecrement() ? _decrement : null,
                icon: const Icon(Icons.remove_circle),
                iconSize: 48,
                color: Colors.red,
              ),
              IconButton(
                onPressed: _canIncrement() ? _increment : null,
                icon: const Icon(Icons.add_circle),
                iconSize: 48,
                color: Colors.green,
              ),
            ],
          ),
        ],
      ),
      actions: [
        if (_step > 1)
          TextButton(
            onPressed: () {
              setState(() {
                _step--;
              });
            },
            child: const Text('Back'),
          ),
        TextButton(
          onPressed: _nextOrComplete,
          child: Text(_step == 3 ? 'Done' : 'Next'),
        ),
      ],
    );
  }

  String _getStepTitle() {
    switch (_step) {
      case 1:
        return 'First Attempt';
      case 2:
        return 'Second Attempt';
      case 3:
        return 'Neighbors';
      default:
        return '';
    }
  }

  String _getStepDescription() {
    switch (_step) {
      case 1:
        return 'How many kubbs went out of bounds on the first attempt?';
      case 2:
        return 'How many went out on the second attempt?';
      case 3:
        return 'How many kubbs are neighbors (stacked on other kubbs)?';
      default:
        return '';
    }
  }

  int _getCurrentValue() {
    switch (_step) {
      case 1:
        return _firstAttemptOut;
      case 2:
        return _secondAttemptOut;
      case 3:
        return _neighborCount;
      default:
        return 0;
    }
  }

  bool _canDecrement() {
    return _getCurrentValue() > 0;
  }

  bool _canIncrement() {
    switch (_step) {
      case 1:
        return _firstAttemptOut < widget.totalKubbs;
      case 2:
        return _secondAttemptOut < _firstAttemptOut;
      case 3:
        return _neighborCount < widget.totalKubbs;
      default:
        return false;
    }
  }

  void _decrement() {
    setState(() {
      switch (_step) {
        case 1:
          _firstAttemptOut--;
          break;
        case 2:
          _secondAttemptOut--;
          break;
        case 3:
          _neighborCount--;
          break;
      }
    });
  }

  void _increment() {
    setState(() {
      switch (_step) {
        case 1:
          _firstAttemptOut++;
          break;
        case 2:
          _secondAttemptOut++;
          break;
        case 3:
          _neighborCount++;
          break;
      }
    });
  }

  void _nextOrComplete() {
    if (_step == 1 && _firstAttemptOut == 0) {
      // Skip second attempt if all kubbs were in bounds
      setState(() {
        _step = 3;
      });
    } else if (_step < 3) {
      setState(() {
        _step++;
      });
    } else {
      widget.onComplete(_firstAttemptOut, _secondAttemptOut, _neighborCount);
    }
  }
}

// ============================================================================
// Hit Recording Dialog
// ============================================================================

class _HitRecordingDialog extends StatefulWidget {
  final int remainingKubbs;
  final Function(int kubbsHit) onConfirm;
  final VoidCallback onCancel;

  const _HitRecordingDialog({
    required this.remainingKubbs,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  State<_HitRecordingDialog> createState() => _HitRecordingDialogState();
}

class _HitRecordingDialogState extends State<_HitRecordingDialog> {
  int _kubbsHit = 1;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('How many kubbs did you hit?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${widget.remainingKubbs} remaining',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _kubbsHit.toString(),
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: _kubbsHit > 1
                    ? () {
                        setState(() {
                          _kubbsHit--;
                        });
                      }
                    : null,
                icon: const Icon(Icons.remove_circle),
                iconSize: 48,
                color: Colors.red,
              ),
              IconButton(
                onPressed: _kubbsHit < widget.remainingKubbs
                    ? () {
                        setState(() {
                          _kubbsHit++;
                        });
                      }
                    : null,
                icon: const Icon(Icons.add_circle),
                iconSize: 48,
                color: Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // "All" button
          ElevatedButton.icon(
            onPressed: _kubbsHit < widget.remainingKubbs
                ? () {
                    setState(() {
                      _kubbsHit = widget.remainingKubbs;
                    });
                  }
                : null,
            icon: const Icon(Icons.done_all),
            label: const Text('All'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: widget.onCancel,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => widget.onConfirm(_kubbsHit),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

