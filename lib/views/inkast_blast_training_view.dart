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
  final ScrollController _scorecardScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _startNewSession();
  }

  @override
  void dispose() {
    _scorecardScrollController.dispose();
    super.dispose();
  }

  void _scrollScorecardToEnd() {
    // Scroll to the end after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scorecardScrollController.hasClients) {
        _scorecardScrollController.animateTo(
          _scorecardScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
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
    
    // Scroll to show the most recent round
    _scrollScorecardToEnd();
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

    final totalScore = _calculateHandicap();
    final phaseStats = _calculatePhaseStats();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Overall session stats
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session Summary',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text('Total Rounds: ${_session!.totalRounds}'),
                    Text('Total Score: ${totalScore >= 0 ? '+$totalScore' : totalScore}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Phase-specific stats
              ...phaseStats.entries.map((entry) {
                final phase = entry.key;
                final stats = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getPhaseColor(phase).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _getPhaseColor(phase)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${phase.displayName} Phase',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getPhaseColor(phase),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text('Rounds: ${stats['rounds']}'),
                      Text('First Inkast Accuracy: ${(stats['firstInkastAccuracy'] * 100).toStringAsFixed(1)}%'),
                      Text(
                        'Neighbors: ${stats['neighbors']}',
                        style: const TextStyle(color: Colors.green),
                      ),
                      Text(
                        'Penalty kubbs: ${stats['penaltyKubbs']}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      Text(
                        'A-Lines: ${stats['aLines']}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      Text('Score: ${stats['score'] >= 0 ? '+${stats['score']}' : stats['score']}'),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
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

  Map<GamePhase, Map<String, dynamic>> _calculatePhaseStats() {
    final phaseStats = <GamePhase, Map<String, dynamic>>{};
    
    for (final phase in GamePhase.values) {
      if (phase == GamePhase.all) continue; // Skip "All Phases" as it's not a specific phase
      
      final phaseRounds = _session!.completedRounds.where((round) {
        final kubbCount = round.inkastKubbs;
        return kubbCount >= phase.minKubbs && kubbCount <= phase.maxKubbs;
      }).toList();
      
      if (phaseRounds.isEmpty) continue; // Skip phases with no rounds
      
      final totalInkastKubbs = phaseRounds.fold(0, (sum, round) => sum + round.inkastKubbs);
      final firstAttemptSuccess = totalInkastKubbs - phaseRounds.fold(0, (sum, round) => sum + round.kubbsOutFirstAttempt);
      final firstInkastAccuracy = totalInkastKubbs > 0 ? firstAttemptSuccess / totalInkastKubbs : 0.0;
      
      final neighbors = phaseRounds.fold(0, (sum, round) => sum + round.neighborKubbs);
      final penaltyKubbs = phaseRounds.fold(0, (sum, round) => sum + round.penaltyKubbs);
      final aLines = phaseRounds.where((round) => round.batonsUsed > 6).length;
      final score = phaseRounds.fold(0, (sum, round) => sum - round.performanceVsTarget);
      
      phaseStats[phase] = {
        'rounds': phaseRounds.length,
        'firstInkastAccuracy': firstInkastAccuracy,
        'neighbors': neighbors,
        'penaltyKubbs': penaltyKubbs,
        'aLines': aLines,
        'score': score,
      };
    }
    
    return phaseStats;
  }

  Color _getPhaseColor(GamePhase phase) {
    switch (phase) {
      case GamePhase.early:
        return Colors.green;
      case GamePhase.mid:
        return Colors.orange;
      case GamePhase.end:
        return Colors.red;
      case GamePhase.all:
        return Colors.blue;
    }
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
                  if (_roundPhase == RoundPhase.roundComplete) _buildSessionSummary(),
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
                  _getRoundDisplayText(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  _getCurrentPhaseDisplayName(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey[600],
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildGolfScorecard(),
          ],
        ),
      ),
    );
  }

  Widget _buildGolfScorecard() {
    final completedRounds = _session!.completedRounds;
    final totalHandicap = _calculateHandicap();
    
    if (completedRounds.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'No completed rounds yet',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Fixed labels column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                child: Text(
                  'Round:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Text(
                  'Par:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Text(
                  'Score:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          
          // Scrollable data section
          Expanded(
            child: SingleChildScrollView(
              controller: _scorecardScrollController,
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Round numbers row
                  Row(
                    children: List.generate(completedRounds.length, (index) {
                      return SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  
                  // Par row
                  Row(
                    children: List.generate(completedRounds.length, (index) {
                      return SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            '${completedRounds[index].targetBatons}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  
                  // Score row
                  Row(
                    children: List.generate(completedRounds.length, (index) {
                      final performance = completedRounds[index].performanceVsTarget;
                      final score = -performance; // Negative because under target is good
                      final scoreText = score >= 0 ? '+$score' : score.toString();
                      final scoreColor = score < 0 ? Colors.green : score > 0 ? Colors.red : Colors.grey;
                      
                      return SizedBox(
                        width: 40,
                        child: Center(
                          child: Text(
                            scoreText,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: scoreColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          
          // Fixed total column
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 20,
                child: Text(
                  'Total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Text(
                  'Score:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 20,
                child: Text(
                  totalHandicap >= 0 ? '+$totalHandicap' : totalHandicap.toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: totalHandicap < 0 ? Colors.green : totalHandicap > 0 ? Colors.red : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getRoundDisplayText() {
    if (_roundPhase == RoundPhase.roundComplete) {
      // Round is complete, waiting for "Next Round" button
      final rounds = _session!.totalRounds;
      return rounds == 1 ? 'After 1 Round' : 'After $rounds Rounds';
    } else {
      // Currently in a round (inkast or blasting phase)
      return 'Current Round: ${_session!.rounds.length + 1}';
    }
  }

  String _getCurrentPhaseDisplayName() {
    if (_currentRound == null) {
      return widget.gamePhase.displayName;
    }
    
    // If round is complete, show the original session phase
    if (_roundPhase == RoundPhase.roundComplete) {
      return widget.gamePhase.displayName;
    }
    
    // During active rounds, determine phase based on current round's kubb count
    final kubbCount = _currentRound!.inkastKubbs;
    
    if (kubbCount >= 1 && kubbCount <= 3) {
      return 'Early Game';
    } else if (kubbCount >= 4 && kubbCount <= 7) {
      return 'Mid Game';
    } else if (kubbCount >= 8 && kubbCount <= 10) {
      return 'End Game';
    } else {
      return 'All Phases';
    }
  }

  Widget _buildSessionSummary() {
    final handicap = _calculateHandicap();
    final firstInkastAccuracy = _calculateFirstInkastAccuracy();
    final penaltyKubbs = _session!.totalPenaltyKubbs;
    final neighbors = _session!.totalNeighborKubbs;
    final aLinesLeft = _calculateALinesLeft();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStatItem('Current Handicap', handicap >= 0 ? '+$handicap' : handicap.toString()),
                _buildSummaryStatItem('First inkast Accuracy', '${(firstInkastAccuracy * 100).toStringAsFixed(1)}%'),
                _buildSummaryStatItem('Penalty kubbs', penaltyKubbs.toString()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStatItem('Neighbors', neighbors.toString()),
                _buildSummaryStatItem('A-Lines left', aLinesLeft.toString()),
                const SizedBox(), // Empty space for alignment
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStatItem(String label, String value) {
    return Expanded(
      child: Column(
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
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
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

  int _calculateHandicap() {
    int handicap = 0;
    for (final round in _session!.rounds) {
      // performanceVsTarget is target - used, so positive means under target (good)
      // We want handicap to show + for over target (bad), - for under target (good)
      handicap -= round.performanceVsTarget;
    }
    return handicap;
  }

  double _calculateFirstInkastAccuracy() {
    if (_session!.totalInkastKubbs == 0) return 0.0;
    final firstAttemptSuccess = _session!.totalInkastKubbs - _session!.rounds.fold(0, (sum, round) => sum + round.kubbsOutFirstAttempt);
    return firstAttemptSuccess / _session!.totalInkastKubbs;
  }

  int _calculateALinesLeft() {
    int aLinesLeft = 0;
    for (final round in _session!.rounds) {
      if (round.batonsUsed > 6) {
        aLinesLeft++;
      }
    }
    return aLinesLeft;
  }

  int _getKubbsHitForBaton(int batonIndex) {
    if (_currentRound == null || batonIndex >= _currentRound!.batonThrows.length) {
      return 0;
    }
    
    final batonThrow = _currentRound!.batonThrows[batonIndex];
    return batonThrow.isHit ? batonThrow.kubbsHit : 0;
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
                    ? '-${_currentRound!.performanceVsTarget} (under target!)'
                    : _currentRound!.performanceVsTarget < 0
                        ? '+${_currentRound!.performanceVsTarget.abs()} (over target)'
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
            const SizedBox(height: 16),
            _buildInkastVisualization(),
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

  Widget _buildInkastVisualization() {
    final totalKubbs = _currentRound!.inkastKubbs;
    
    return Column(
      children: [
        // In-bounds kubbs
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.green.shade700,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                'In Bounds',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: List.generate(totalKubbs, (index) {
                  return Image.asset(
                    'assets/images/sw_kubb1.png',
                    width: 30,
                    height: 30,
                    fit: BoxFit.contain,
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Out-of-bounds kubbs
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.red.shade700,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Out of Bounds',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Record results to see out-of-bounds kubbs',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBlastingPhase() {
    if (_currentRound == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(
              'Blasting Phase',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Stand up the kubbs and clear them',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _buildPitchVisualization(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _addBatonThrow(isHit: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.close, size: 32),
                        SizedBox(height: 4),
                        Text(
                          'MISS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _showHitRecordingDialog(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.check, size: 32),
                        SizedBox(height: 4),
                        Text(
                          'HIT',
                          style: TextStyle(
                            fontSize: 16,
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

  Widget _buildPitchVisualization() {
    final kubbsInBounds = _currentRound!.totalKubbsInBounds;
    final penaltyKubbs = _currentRound!.penaltyKubbs;
    final totalKubbsToClear = kubbsInBounds + penaltyKubbs;
    final kubbsKnockedDown = _currentRound!.kubbsClearedFirstThrow;
    final batonsUsed = _currentRound!.batonsUsed;
    final targetBatons = _currentRound!.targetBatons;

    return Column(
      children: [
        // Target and stats in one row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue, width: 1),
              ),
              child: Text(
                'Target: $targetBatons',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              'Used: $batonsUsed / $targetBatons',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Combined kubbs visualization
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.brown.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.brown.shade700,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Kubbs to Clear ($totalKubbsToClear)',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade700,
                    ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  // In-bounds kubbs first
                  ...List.generate(kubbsInBounds, (index) {
                    final isKnockedDown = index < kubbsKnockedDown;
                    return Image.asset(
                      isKnockedDown ? 'assets/images/sw_down_kubb1.png' : 'assets/images/sw_kubb1.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.contain,
                    );
                  }),
                  // Penalty kubbs last
                  ...List.generate(penaltyKubbs, (index) {
                    final penaltyIndex = kubbsInBounds + index;
                    final isKnockedDown = penaltyIndex < kubbsKnockedDown;
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade700, width: 1),
                      ),
                      child: Image.asset(
                        isKnockedDown ? 'assets/images/sw_down_kubb1.png' : 'assets/images/sw_kubb1.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.contain,
                      ),
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Batons visualization
        Wrap(
          spacing: 4,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: List.generate(6, (index) {
            final isUsed = index < batonsUsed;
            final kubbsHit = isUsed ? _getKubbsHitForBaton(index) : 0;
            
            // Determine colors
            Color borderColor = isUsed ? Colors.grey.shade400 : Colors.green.shade700;
            Color badgeColor;
            if (kubbsHit == 0) {
              badgeColor = Colors.red.shade700; // Red for misses
            } else if (kubbsHit <= 3) {
              badgeColor = Colors.green.shade700; // Green for 1-3 kubbs
            } else {
              badgeColor = Colors.blue.shade700; // Blue for 4+ kubbs
            }
            
            return Stack(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: borderColor,
                      width: 2,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Opacity(
                      opacity: isUsed ? 0.6 : 1.0, // Gray out used batons
                      child: Image.asset(
                        'assets/images/sw_baton.png',
                        width: 28,
                        height: 28,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                if (isUsed)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Center(
                        child: Text(
                          kubbsHit.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildRoundCompletePhase() {
    if (_currentRound == null) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
                const SizedBox(width: 8),
                Text(
                  'Round Complete!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Used ${_currentRound!.batonsUsed} batons'),
            Text('Target was ${_currentRound!.targetBatons} batons'),
            const SizedBox(height: 8),
            Text(
              _currentRound!.performanceVsTarget > 0
                  ? '-${_currentRound!.performanceVsTarget} under target! 🎉'
                  : _currentRound!.performanceVsTarget < 0
                      ? '+${_currentRound!.performanceVsTarget.abs()} over target'
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
    
    // Calculate remaining kubbs (including penalty kubbs)
    final totalKubbsToClear = _currentRound!.totalKubbsInBounds + _currentRound!.penaltyKubbs;
    final remainingKubbs = totalKubbsToClear - _currentRound!.kubbsClearedFirstThrow;
    
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
          const SizedBox(height: 16),
          _buildInkastDialogVisualization(),
          const SizedBox(height: 16),
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

  Widget _buildInkastDialogVisualization() {
    final totalKubbs = widget.totalKubbs;
    final outOfBounds = _getCurrentValue();
    final inBounds = totalKubbs - outOfBounds;
    
    // For neighbors step, show the penalty kubbs from second attempt
    if (_step == 3) {
      final penaltyKubbs = _secondAttemptOut;
      final remainingInBounds = totalKubbs - penaltyKubbs;
      
      return Column(
        children: [
          // In-bounds kubbs
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.green.shade700,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'In Bounds ($remainingInBounds)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: List.generate(remainingInBounds, (index) {
                    return Image.asset(
                      'assets/images/sw_kubb1.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    );
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Penalty kubbs (from second attempt)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.red.shade700,
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Penalty Kubbs ($penaltyKubbs)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: List.generate(penaltyKubbs, (index) {
                    return Image.asset(
                      'assets/images/sw_kubb1.png',
                      width: 24,
                      height: 24,
                      fit: BoxFit.contain,
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      );
    }
    
    // For first and second attempt steps
    return Column(
      children: [
        // In-bounds kubbs
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.green.shade700,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                'In Bounds ($inBounds)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: List.generate(inBounds, (index) {
                  return Image.asset(
                    'assets/images/sw_kubb1.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Out-of-bounds kubbs
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.red.shade700,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                _step == 2 ? 'Penalty Kubbs ($outOfBounds)' : 'Out of Bounds ($outOfBounds)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: List.generate(outOfBounds, (index) {
                  return Image.asset(
                    'assets/images/sw_kubb1.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  );
                }),
              ),
            ],
          ),
        ),
      ],
    );
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

