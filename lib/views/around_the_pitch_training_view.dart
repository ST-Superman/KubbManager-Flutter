import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/practice_session.dart';
import '../services/session_manager.dart';

/// Around the Pitch training mode - Clear all 10 baseline kubbs + king
class AroundThePitchTrainingView extends StatefulWidget {
  const AroundThePitchTrainingView({super.key});

  @override
  State<AroundThePitchTrainingView> createState() => _AroundThePitchTrainingViewState();
}

class _AroundThePitchTrainingViewState extends State<AroundThePitchTrainingView> {
  PracticeSession? _session;
  int _targetScore = 20;
  bool _isLoading = true;
  
  // Track which kubbs are down (indexes 0-4 for baseline 1, 5-9 for baseline 2)
  final List<bool> _kubbsDown = List.filled(10, false);
  bool _kingDown = false;
  int _currentBaseline = 1; // Which baseline we're currently throwing at
  int _throwsInCurrentSet = 0; // Track throws in current 6-baton set

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid context access before widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSession();
    });
  }

  Future<void> _initSession() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    final sessionManager = context.read<SessionManager>();
    
    // Check for active session
    final activeSession = sessionManager.activePracticeSession;
    if (activeSession != null && 
        activeSession.sessionType == SessionType.aroundThePitch &&
        !activeSession.isComplete) {
      _session = activeSession;
      _targetScore = activeSession.targetScore;
      _restoreSessionState();
    } else {
      // Show target configuration dialog
      await _showTargetDialog();
      
      // Create new session
      _session = await sessionManager.startPracticeSession(
        target: 999, // Not used for Around the Pitch, but required field
        sessionType: SessionType.aroundThePitch,
        targetScore: _targetScore,
      );
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _restoreSessionState() {
    if (_session == null) return;
    
    final round = _session!.currentRound;
    if (round == null) return;
    
    // Restore kubb states from throws and calculate current set progress
    int kubbThrows = 0;
    for (final throw_ in round.batonThrows) {
      if (throw_.throwType == ThrowType.kubb) {
        kubbThrows++;
        if (throw_.isHit) {
          final baseline = throw_.baselineNumber ?? 1;
          final index = _getNextKubbIndexForBaseline(baseline);
          if (index != -1) {
            _kubbsDown[index] = true;
          }
        }
      } else if (throw_.throwType == ThrowType.king && throw_.isHit) {
        _kingDown = true;
      }
    }
    
    // Calculate throws in current set (modulo 6)
    _throwsInCurrentSet = kubbThrows % 6;
    
    // Set current baseline based on which baselines have kubbs remaining
    final baseline1Empty = _isBaselineEmpty(1);
    final baseline2Empty = _isBaselineEmpty(2);
    
    if (!baseline1Empty && !baseline2Empty) {
      // Both baselines have kubbs, start with baseline 1
      _currentBaseline = 1;
    } else if (!baseline1Empty) {
      // Only baseline 1 has kubbs
      _currentBaseline = 1;
    } else if (!baseline2Empty) {
      // Only baseline 2 has kubbs
      _currentBaseline = 2;
    }
    // If both are empty, stay on current baseline (will throw at king)
  }

  int _getNextKubbIndexForBaseline(int baseline) {
    final startIndex = baseline == 1 ? 0 : 5;
    final endIndex = baseline == 1 ? 5 : 10;
    
    for (int i = startIndex; i < endIndex; i++) {
      if (!_kubbsDown[i]) {
        return i;
      }
    }
    return -1;
  }

  bool _isBaselineEmpty(int baseline) {
    final startIndex = baseline == 1 ? 0 : 5;
    final endIndex = baseline == 1 ? 5 : 10;
    
    for (int i = startIndex; i < endIndex; i++) {
      if (!_kubbsDown[i]) {
        return false; // Found a kubb still standing
      }
    }
    return true; // All kubbs on this baseline are down
  }

  void _switchToNextAvailableBaseline() {
    final baseline1Empty = _isBaselineEmpty(1);
    final baseline2Empty = _isBaselineEmpty(2);
    
    if (baseline1Empty && baseline2Empty) {
      // Both baselines are empty, stay on current baseline (will throw at king)
      return;
    } else if (baseline1Empty) {
      // Baseline 1 is empty, switch to baseline 2
      _currentBaseline = 2;
    } else if (baseline2Empty) {
      // Baseline 2 is empty, switch to baseline 1
      _currentBaseline = 1;
    } else {
      // Both baselines have kubbs, switch to the other one
      _currentBaseline = _currentBaseline == 1 ? 2 : 1;
    }
  }

  Future<void> _showTargetDialog() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _AroundThePitchTargetSelectionScreen(
          initialTarget: _targetScore,
          onTargetSelected: (target) {
            _targetScore = target;
            Navigator.of(context).pop();
          },
        ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Around the Pitch'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsMenu,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(),
          _buildWarningBanner(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _buildPitchView(),
                  const SizedBox(height: 12),
                  _buildControlButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    final totalKubbsDown = _kubbsDown.where((k) => k).length;
    final throws = _session?.totalBatons ?? 0;
    
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Throws', '$throws', Colors.blue),
          _buildStatItem('Target', '$_targetScore', Colors.orange),
          _buildStatItem('Kubbs Down', '$totalKubbsDown/10', Colors.green),
          _buildStatItem('Remaining', '${_targetScore - throws}', 
              throws > _targetScore ? Colors.red : Colors.grey),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBanner() {
    final throws = _session?.totalBatons ?? 0;
    final totalKubbsDown = _kubbsDown.where((k) => k).length;
    final kubbsRemaining = 10 - totalKubbsDown;
    final kingRemaining = _kingDown ? 0 : 1;
    final piecesRemaining = kubbsRemaining + kingRemaining; // Total pieces left to knock down
    final throwsRemaining = _targetScore - throws;
    
    // Calculate buffer: extra throws beyond what's needed (if perfect)
    final buffer = throwsRemaining - piecesRemaining;
    
    // Don't show banner if session is complete
    if (_kingDown) return const SizedBox.shrink();
    
    // Determine warning level based on buffer
    String warningMessage = '';
    Color warningColor = Colors.green;
    IconData warningIcon = Icons.check_circle;
    
    if (throws >= _targetScore) {
      // Already over target
      warningMessage = '🚨 You\'ve exceeded your target! ($throws/$_targetScore throws)';
      warningColor = Colors.red.shade700;
      warningIcon = Icons.error;
    } else if (buffer <= 0) {
      // Must be perfect (or already impossible)
      if (buffer < 0) {
        warningMessage = '⛔ Target impossible! Need ${piecesRemaining - throwsRemaining} fewer kubbs';
        warningColor = Colors.red.shade900;
        warningIcon = Icons.cancel;
      } else {
        warningMessage = '🎯 Perfect required! Need $piecesRemaining hits with $throwsRemaining throws left';
        warningColor = Colors.red;
        warningIcon = Icons.gps_fixed;
      }
    } else if (buffer == 1) {
      // Only 1 miss allowed
      warningMessage = '⚠️ Critical! Only 1 miss allowed (need $piecesRemaining hits from $throwsRemaining throws)';
      warningColor = Colors.red;
      warningIcon = Icons.warning;
    } else if (buffer >= 2 && buffer <= 4) {
      // Yellow zone: 2-4 extra throws
      warningMessage = '⚡ Getting tight! You can afford $buffer misses';
      warningColor = Colors.amber.shade700;
      warningIcon = Icons.info;
    } else {
      // Green zone: 5+ extra throws - don't show banner
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      color: warningColor.withValues(alpha: 0.2),
      child: Row(
        children: [
          Icon(warningIcon, color: warningColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              warningMessage,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: warningColor.withValues(alpha: 0.95),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPitchView() {
    return Column(
      children: [
        // Baseline 1 (Top)
        _buildBaseline(1, 'Baseline 1'),
        const SizedBox(height: 16),
        
        // King in the center
        _buildKing(),
        const SizedBox(height: 16),
        
        // Baseline 2 (Bottom)
        _buildBaseline(2, 'Baseline 2'),
      ],
    );
  }

  Widget _buildBaseline(int baselineNumber, String label) {
    final startIndex = baselineNumber == 1 ? 0 : 5;
    final isSelected = _currentBaseline == baselineNumber;
    
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.blue : Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Colors.blue.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Colors.blue : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (i) {
              final kubbIndex = startIndex + i;
              return _buildKubb(_kubbsDown[kubbIndex], i);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildKubb(bool isDown, int index) {
    // Alternate between kubb1 and kubb2 images
    final kubbImage = index % 2 == 0 
        ? 'assets/images/sw_kubb1.png'
        : 'assets/images/sw_kubb2.png';
    final downKubbImage = index % 2 == 0 
        ? 'assets/images/sw_down_kubb1.png'
        : 'assets/images/sw_down_kubb2.png';
    
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: isDown ? 0.3 : 1.0,
      child: Image.asset(
        isDown ? downKubbImage : kubbImage,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildKing() {
    final allKubbsDown = _kubbsDown.every((k) => k);
    
    return Column(
      children: [
        Text(
          'KING',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: allKubbsDown ? Colors.amber : Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _kingDown ? 0.3 : 1.0,
          child: Container(
            decoration: allKubbsDown && !_kingDown
                ? BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.amber.withValues(alpha: 0.5),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  )
                : null,
            child: Image.asset(
              'assets/images/sw_king.png',
              width: 50,
              height: 50,
              fit: BoxFit.contain,
              color: !allKubbsDown ? Colors.grey : null,
              colorBlendMode: !allKubbsDown ? BlendMode.saturation : null,
            ),
          ),
        ),
        if (allKubbsDown && !_kingDown)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '👑 Available!',
              style: TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControlButtons() {
    final allKubbsDown = _kubbsDown.every((k) => k);
    
    return Column(
      children: [
        // Current baseline indicator and set progress
        if (!allKubbsDown) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue),
            ),
            child: Column(
              children: [
                Text(
                  'Throwing at Baseline $_currentBaseline',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Throws in current set: $_throwsInCurrentSet/6',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        
        // Hit/Miss buttons (Miss on left to match standard 8 meter)
        const Text(
          'Record Throw:',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _kingDown ? null : () => _recordThrow(false),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.close, size: 28),
                label: const Text(
                  'MISS',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _kingDown ? null : () => _recordThrow(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.check, size: 28),
                label: const Text(
                  'HIT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
        
        if (_kingDown) ...[
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _completeSession,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              minimumSize: const Size(double.infinity, 50),
            ),
            icon: const Icon(Icons.celebration, size: 28),
            label: const Text(
              'Complete Session',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ],
    );
  }


  Future<void> _recordThrow(bool isHit) async {
    if (_session == null) return;
    
    final allKubbsDown = _kubbsDown.every((k) => k);
    final throwType = allKubbsDown ? ThrowType.king : ThrowType.kubb;
    
    // Record throw in session first
    final round = _session!.currentRound;
    if (round != null) {
      round.addBatonThrow(
        isHit: isHit,
        throwType: throwType,
        baselineNumber: throwType == ThrowType.kubb ? _currentBaseline : null,
      );
    }
    
    _session!.addBatonResult(isHit);
    
    // Update visual state based on hit
    if (isHit) {
      if (throwType == ThrowType.king) {
        _kingDown = true;
      } else {
        // Find next available kubb on current baseline
        final nextIndex = _getNextKubbIndexForBaseline(_currentBaseline);
        if (nextIndex != -1) {
          _kubbsDown[nextIndex] = true;
        }
      }
    }
    
    // Increment throws in current set
    _throwsInCurrentSet++;
    
    // Check if we need to switch baselines
    if (throwType == ThrowType.kubb) {
      // Check if current baseline is now empty
      if (_isBaselineEmpty(_currentBaseline)) {
        _switchToNextAvailableBaseline();
        _throwsInCurrentSet = 0; // Reset throw counter for new baseline
      }
      // Check if we've thrown 6 batons in current set
      else if (_throwsInCurrentSet >= 6) {
        _switchToNextAvailableBaseline();
        _throwsInCurrentSet = 0; // Reset throw counter for new baseline
      }
    }
    
    // Save session and update UI
    final sessionManager = context.read<SessionManager>();
    await sessionManager.updatePracticeSession(_session!);
    
    // Force UI update to show new throw count
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _completeSession() async {
    if (_session == null) return;
    
    _session!.completeSession();
    
    final sessionManager = context.read<SessionManager>();
    await sessionManager.updatePracticeSession(_session!);
    
    // Show completion dialog
    await _showCompletionDialog();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showCompletionDialog() async {
    final throws = _session?.totalBatons ?? 0;
    final metTarget = throws <= _targetScore;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              metTarget ? Icons.celebration : Icons.thumbs_up_down,
              color: metTarget ? Colors.green : Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 12),
            Text(metTarget ? 'Great Job!' : 'Session Complete!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Total Throws: $throws',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              'Target: $_targetScore',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            if (metTarget)
              const Text(
                '🎉 You met your target!',
                style: TextStyle(fontSize: 18, color: Colors.green),
                textAlign: TextAlign.center,
              )
            else
              Text(
                'You were ${throws - _targetScore} throws over target.\nKeep practicing!',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSettingsMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Reset Round'),
              subtitle: const Text('Clear current round and start over'),
              onTap: () {
                Navigator.pop(context);
                _confirmReset();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exit_to_app, color: Colors.red),
              title: const Text('Abandon Session'),
              subtitle: const Text('Exit without saving progress'),
              onTap: () {
                Navigator.pop(context);
                _confirmAbandon();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Round?'),
        content: const Text('This will clear your current progress and start over.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _resetRound();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  void _confirmAbandon() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon Session?'),
        content: const Text('Your progress will not be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              navigator.pop(); // Close dialog
              
              if (_session != null) {
                final sessionManager = context.read<SessionManager>();
                await sessionManager.deletePracticeSession(_session!.id);
              }
              
              if (mounted) {
                navigator.pop(); // Close view
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );
  }

  void _resetRound() {
    setState(() {
      _kubbsDown.fillRange(0, 10, false);
      _kingDown = false;
      _currentBaseline = 1;
    });
    
    if (_session != null) {
      _session!.resetCurrentRound();
      _session!.totalBatons = 0;
      _session!.totalKubbs = 0;
      
      final sessionManager = context.read<SessionManager>();
      sessionManager.updatePracticeSession(_session!);
    }
  }
}

/// Around the Pitch target selection screen
class _AroundThePitchTargetSelectionScreen extends StatefulWidget {
  final int initialTarget;
  final Function(int) onTargetSelected;

  const _AroundThePitchTargetSelectionScreen({
    required this.initialTarget,
    required this.onTargetSelected,
  });

  @override
  State<_AroundThePitchTargetSelectionScreen> createState() =>
      _AroundThePitchTargetSelectionScreenState();
}

class _AroundThePitchTargetSelectionScreenState extends State<_AroundThePitchTargetSelectionScreen> {
  int _selectedTarget = 20;
  int? _bestScore;
  double? _avgScore;

  final List<int> _presetTargets = [11, 15, 20, 25];

  @override
  void initState() {
    super.initState();
    _selectedTarget = widget.initialTarget;
    _loadUserStats();
  }

  Future<void> _loadUserStats() async {
    final sessionManager = context.read<SessionManager>();
    final allSessions = await sessionManager.getAllPracticeSessions();
    final aroundPitchSessions = allSessions
        .where((s) => s.isComplete && s.sessionType == SessionType.aroundThePitch)
        .toList();
    
    if (aroundPitchSessions.isNotEmpty) {
      setState(() {
        _bestScore = aroundPitchSessions
            .map((s) => s.totalBatons)
            .reduce((a, b) => a < b ? a : b);
        _avgScore = aroundPitchSessions.fold(0, (sum, s) => sum + s.totalBatons) / 
            aroundPitchSessions.length;
      });
    }
  }

  void _decreaseTarget() {
    setState(() {
      if (_selectedTarget > 11) {
        _selectedTarget--;
      }
    });
  }

  void _increaseTarget() {
    setState(() {
      _selectedTarget++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Around the Pitch'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Image.asset(
              'assets/icons/aroundThePitch.png',
              width: 50,
              height: 50,
              color: Colors.blue,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(height: 12),
            Text(
              'Set Your Target',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'How many throws to clear all 10 baseline kubbs + king?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),

            // User's stats (if available)
            if (_bestScore != null && _avgScore != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Column(
                  children: [
                    Text(
                      'Your Stats',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            Text(
                              '$_bestScore',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Text(
                              'Best',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.green.shade300,
                        ),
                        Column(
                          children: [
                            Text(
                              _avgScore!.toStringAsFixed(1),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const Text(
                              'Average',
                              style: TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Current target with +/- buttons
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Minus button
                    IconButton(
                      onPressed: _selectedTarget > 11 ? _decreaseTarget : null,
                      icon: const Icon(Icons.remove_circle_outline),
                      iconSize: 36,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 12),
                    
                    // Target number
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_selectedTarget',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Plus button
                    IconButton(
                      onPressed: _increaseTarget,
                      icon: const Icon(Icons.add_circle_outline),
                      iconSize: 36,
                      color: Colors.blue,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Preset target buttons
            Text(
              'Quick Select',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _presetTargets.map((target) {
                final isPerfect = target == 11;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3.0),
                    child: Stack(
                      children: [
                        OutlinedButton(
                          onPressed: () => setState(() => _selectedTarget = target),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: _selectedTarget == target
                                  ? Colors.blue
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (isPerfect)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Perfect',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            
            const SizedBox(height: 20),

            // Start button
            ElevatedButton(
              onPressed: () => widget.onTargetSelected(_selectedTarget),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text(
                'Start Practice',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

