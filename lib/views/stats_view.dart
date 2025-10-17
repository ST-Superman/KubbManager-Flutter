import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session_manager.dart';
import '../services/database_service.dart';
import '../models/practice_session.dart';
import '../models/inkast_blast_session.dart';

/// Statistics view for tracking progress and performance over time
class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> with TickerProviderStateMixin {
  late TabController _tabController;
  List<PracticeSession> _allSessions = [];
  List<InkastBlastSession> _allInkastBlastSessions = [];
  bool _isLoading = true;
  
  // Phase filter dropdowns
  GamePhase _selectedInkastPhase = GamePhase.all;
  GamePhase _selectedBlastPhase = GamePhase.all;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSessions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final sessionManager = context.read<SessionManager>();
    _allSessions = await sessionManager.getAllPracticeSessions();
    _allInkastBlastSessions = await sessionManager.getAllInkastBlastSessions();
    setState(() => _isLoading = false);
  }

  void _showDataManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.red),
            SizedBox(width: 8),
            Text('Manage Data'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Delete training data:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildDataOption(
              'Clear All 8M Training',
              '${_allSessions.where((s) => s.sessionType == SessionType.standard).length} sessions',
              Colors.blue,
              () => _confirmDelete('all_8m'),
            ),
            const SizedBox(height: 8),
            _buildDataOption(
              'Clear Around the Pitch',
              '${_allSessions.where((s) => s.sessionType == SessionType.aroundThePitch).length} sessions',
              Colors.green,
              () => _confirmDelete('all_around_pitch'),
            ),
            const SizedBox(height: 8),
            _buildDataOption(
              'Clear Inkast & Blast',
              '${_allInkastBlastSessions.length} sessions',
              Colors.deepOrange,
              () => _confirmDelete('all_inkast_blast'),
            ),
            const SizedBox(height: 8),
            _buildDataOption(
              'Clear All Data',
              '${_allSessions.length + _allInkastBlastSessions.length} total sessions',
              Colors.red,
              () => _confirmDelete('all'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildDataOption(String title, String subtitle, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.delete_outline, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(String type) async {
    Navigator.of(context).pop(); // Close first dialog

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text(_getDeleteMessage(type)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performDelete(type);
    }
  }

  String _getDeleteMessage(String type) {
    switch (type) {
      case 'all_8m':
        return 'Delete all Standard 8M Training sessions? This cannot be undone.';
      case 'all_around_pitch':
        return 'Delete all Around the Pitch sessions? This cannot be undone.';
      case 'all_inkast_blast':
        return 'Delete all Inkast & Blast sessions? This cannot be undone.';
      case 'all':
        return 'Delete ALL training data? This will remove all sessions and cannot be undone.';
      default:
        return 'Delete this data? This cannot be undone.';
    }
  }

  Future<void> _performDelete(String type) async {
    final db = DatabaseService.instance;
    int deletedCount = 0;

    try {
      switch (type) {
        case 'all_8m':
          deletedCount = await db.deleteAllPracticeSessions(sessionType: SessionType.standard);
          break;
        case 'all_around_pitch':
          deletedCount = await db.deleteAllPracticeSessions(sessionType: SessionType.aroundThePitch);
          break;
        case 'all_inkast_blast':
          deletedCount = await db.deleteAllInkastBlastSessions();
          break;
        case 'all':
          final practiceCount = await db.deleteAllPracticeSessions();
          final inkastCount = await db.deleteAllInkastBlastSessions();
          deletedCount = practiceCount + inkastCount;
          break;
      }

      // Reload sessions
      await _loadSessions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✓ Deleted $deletedCount session(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        title: const Text('Statistics'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'manage_data') {
                _showDataManagementDialog();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'manage_data',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, size: 20),
                    SizedBox(width: 8),
                    Text('Manage Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(
              text: '8M Training', 
              icon: Image.asset(
                'assets/icons/8meter.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.primary,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            Tab(
              text: 'Inkast/Blast', 
              icon: Image.asset(
                'assets/icons/inkastblast.png',
                width: 24,
                height: 24,
                color: Theme.of(context).colorScheme.primary,
                colorBlendMode: BlendMode.srcIn,
              ),
            ),
            const Tab(text: 'Progress', icon: Icon(Icons.trending_up)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTrainingTab(),
          _buildInkastBlastTab(),
          _buildProgressTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final stats = _calculateOverallStats();
    final recentForm = _calculateRecentForm();
    final inkastBlastRecentForm = _calculateInkastBlastRecentForm();
    final personalRecords = _calculatePersonalRecords();
    final inkastBlastPersonalRecords = _calculateInkastBlastPersonalRecords();
    final weeklySummary = _calculateWeeklySummary();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Training Overview',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Recent Form Comparison - 8 Meters
          _buildRecentFormCard(recentForm),
          const SizedBox(height: 16),
          
          // Recent Form Comparison - Inkast/Blast
          _buildInkastBlastRecentFormCard(inkastBlastRecentForm),
          const SizedBox(height: 16),
          
          // Key metrics cards
          _buildMetricsGrid(stats),
          const SizedBox(height: 24),
          
          // Personal Records
          _buildPersonalRecordsSection(personalRecords, inkastBlastPersonalRecords, stats),
          const SizedBox(height: 24),
          
          // Weekly Summary
          _buildWeeklySummarySection(weeklySummary),
          const SizedBox(height: 24),
          
          // Recent sessions
          _buildRecentSessions(),
        ],
      ),
    );
  }

  Widget _buildTrainingTab() {
    final standardSessions = _allSessions
        .where((s) => s.isComplete && s.sessionType == SessionType.standard)
        .toList();
    final aroundPitchSessions = _allSessions
        .where((s) => s.isComplete && s.sessionType == SessionType.aroundThePitch)
        .toList();
    final allTrainingSessions = [...standardSessions, ...aroundPitchSessions];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '8 Meter Training',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // No sessions message
          if (allTrainingSessions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No training sessions yet.\nStart practicing to see stats!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          
          // Shared Stats (if any sessions exist)
          if (allTrainingSessions.isNotEmpty) ...[
            _buildSharedStatsSection(standardSessions, aroundPitchSessions),
            const SizedBox(height: 32),
          ],
          
          // Standard Mode Section
          if (standardSessions.isNotEmpty) ...[
            _buildStandardModeSection(standardSessions),
            const SizedBox(height: 32),
          ],
          
          // Around the Pitch Section
          if (aroundPitchSessions.isNotEmpty) ...[
            _buildAroundPitchSection(aroundPitchSessions),
            const SizedBox(height: 32),
          ],
        ],
      ),
    );
  }

  Widget _buildSharedStatsSection(
    List<PracticeSession> standardSessions,
    List<PracticeSession> aroundPitchSessions,
  ) {
    final allSessions = [...standardSessions, ...aroundPitchSessions];
    final totalSessions = allSessions.length;
    final totalThrows = allSessions.fold(0, (sum, s) => sum + s.totalBatons);
    final totalHits = allSessions.fold(0, (sum, s) => sum + s.totalKubbs);
    final overallAccuracy = totalThrows > 0 ? totalHits / totalThrows : 0.0;
    
    // King stats across both modes
    final totalKingHits = allSessions.fold(0, (sum, s) => sum + s.totalKingHits);
    final totalKingAttempts = allSessions.fold(0, (sum, s) => sum + s.totalKingThrowAttempts);
    final kingAccuracy = totalKingAttempts > 0 ? totalKingHits / totalKingAttempts : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.analytics, color: Colors.purple, size: 28),
            const SizedBox(width: 12),
            Text(
              'Overall 8M Training',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Combined stats from all 8 meter training modes',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMetricCard(
              'Total Sessions',
              '$totalSessions',
              Icons.fitness_center,
              Colors.purple,
              'Combined Standard and Around the Pitch sessions',
            ),
            _buildMetricCard(
              'Total Throws',
              '$totalThrows',
              Icons.sports,
              Colors.blue,
              'Total batons thrown across all 8M training',
            ),
            _buildMetricCard(
              'Total Hits',
              '$totalHits',
              Icons.gps_fixed,
              Colors.green,
              'Total kubbs knocked down',
            ),
            _buildMetricCard(
              'Overall Accuracy',
              '${(overallAccuracy * 100).toStringAsFixed(1)}%',
              Icons.percent,
              Colors.orange,
              'Combined accuracy across all 8M training',
            ),
            _buildMetricCard(
              'King Hits',
              '$totalKingHits/$totalKingAttempts',
              Icons.emoji_events,
              Colors.amber,
              'King shot success rate across all modes. King accuracy: ${(kingAccuracy * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStandardModeSection(List<PracticeSession> sessions) {
    final totalRounds = sessions.fold(0, (sum, s) => sum + s.completedRounds.length);
    final baselineClears = sessions.fold(0, (sum, s) => sum + s.totalBaselineClears);
    final advancedStats = _calculateAdvancedTrainingStatsForSessions(sessions);
    final longestStreak = _calculateLongestStreakForSessions(sessions);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/icons/8meter.png',
              width: 28,
              height: 28,
              color: Colors.blue,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 12),
            Text(
              'Standard Mode',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${sessions.length} sessions',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Round-based practice with 5 baseline kubbs',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        
        // All Standard Mode Metrics in One Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMetricCard(
              'Total Rounds',
              '$totalRounds',
              Icons.repeat,
              Colors.teal,
              'Total rounds completed in Standard Mode',
            ),
            _buildMetricCard(
              'Baseline Clears',
              '$baselineClears',
              Icons.star,
              Colors.amber,
              'Rounds where all 5 baseline kubbs were knocked down. This doesn\'t require a perfect 6/6 - you just need to clear all 5 kubbs in the round.',
            ),
            _buildMetricCard(
              'First Throw',
              '${(advancedStats.firstThrowAccuracy * 100).toStringAsFixed(1)}%',
              Icons.looks_one,
              Colors.indigo,
              'Your accuracy on the first baton throw of each round. A lower percentage indicates "cold start" issues.',
            ),
            _buildMetricCard(
              'Consistency',
              '${(advancedStats.consistencyScore * 100).toStringAsFixed(1)}%',
              Icons.show_chart,
              Colors.teal,
              'Standard deviation of your session accuracies. Higher score means more consistent performance (less variation).',
            ),
            _buildMetricCard(
              'Clutch Performance',
              '${(advancedStats.clutchAccuracy * 100).toStringAsFixed(1)}%',
              Icons.stars,
              Colors.deepPurple,
              'Your accuracy when 3-4 kubbs are already down. Shows your performance under pressure.',
            ),
            _buildMetricCard(
              'Avg Kubbs/Round',
              advancedStats.avgKubbsPerRound.toStringAsFixed(1),
              Icons.bar_chart,
              Colors.cyan,
              'Average number of baseline kubbs knocked down per round. Higher is better - maximum is 5.0.',
            ),
            _buildMetricCard(
              'Longest Streak',
              '$longestStreak',
              Icons.local_fire_department,
              Colors.red,
              'Longest consecutive baseline clears in a single session.',
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        // Round Progression (Standard Mode only)
        _buildRoundProgressionAnalysisForSessions(sessions),
        const SizedBox(height: 16),
        
        // Session Lengths (Standard Mode only)
        _buildSessionLengthAnalysisForSessions(sessions),
      ],
    );
  }

  Widget _buildAroundPitchSection(List<PracticeSession> sessions) {
    // Calculate Around the Pitch specific stats
    final totalSessions = sessions.length;
    final bestScore = sessions.isEmpty
        ? 0
        : sessions.map((s) => s.totalBatons).reduce((a, b) => a < b ? a : b);
    final avgScore = sessions.isEmpty
        ? 0.0
        : sessions.fold(0, (sum, s) => sum + s.totalBatons) / sessions.length;
    final recentAvg = sessions.isEmpty
        ? 0.0
        : sessions.take(5).fold(0, (sum, s) => sum + s.totalBatons) / 
            (sessions.length < 5 ? sessions.length : 5);
    final metTarget = sessions.where((s) => s.totalBatons <= s.targetScore).length;
    final targetSuccessRate = totalSessions > 0 ? metTarget / totalSessions : 0.0;
    final longestStreak = _calculateAroundPitchLongestStreak(sessions);
    final clutchPerformance = _calculateAroundPitchClutchPerformance(sessions);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(
              'assets/icons/aroundThePitch.png',
              width: 28,
              height: 28,
              color: Colors.blue,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 12),
            Text(
              'Around the Pitch',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '$totalSessions sessions',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Clear all 10 baseline kubbs + king in one continuous session',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMetricCard(
              'Best Score',
              '$bestScore throws',
              Icons.emoji_events,
              Colors.amber,
              'Your best (lowest) score. Perfect is 11 throws.',
            ),
            _buildMetricCard(
              'Average Score',
              '${avgScore.toStringAsFixed(1)} throws',
              Icons.trending_up,
              Colors.blue,
              'Average throws across all sessions.',
            ),
            _buildMetricCard(
              'Recent Average',
              '${recentAvg.toStringAsFixed(1)} throws',
              Icons.history,
              Colors.purple,
              'Average of your last 5 sessions.',
            ),
            _buildMetricCard(
              'Target Success',
              '${(targetSuccessRate * 100).toStringAsFixed(0)}%',
              Icons.check_circle,
              Colors.green,
              '$metTarget of $totalSessions times you met or beat your target.',
            ),
            _buildMetricCard(
              'Longest Streak',
              '$longestStreak',
              Icons.local_fire_department,
              Colors.red,
              'Longest consecutive baton hits within a single session.',
            ),
            _buildMetricCard(
              'Clutch Performance',
              '${(clutchPerformance * 100).toStringAsFixed(1)}%',
              Icons.stars,
              Colors.deepPurple,
              'Your accuracy when you have yellow or red warnings (tight situations).',
            ),
          ],
        ),
      ],
    );
  }

  // ==================== HELPER WIDGETS ====================

  Widget _buildPhaseDropdown({
    required GamePhase selectedPhase,
    required Function(GamePhase) onChanged,
    required String label,
  }) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        DropdownButton<GamePhase>(
          value: selectedPhase,
          onChanged: (GamePhase? newPhase) {
            if (newPhase != null) {
              onChanged(newPhase);
            }
          },
          items: GamePhase.values.map<DropdownMenuItem<GamePhase>>((GamePhase phase) {
            return DropdownMenuItem<GamePhase>(
              value: phase,
              child: Text(phase.displayName),
            );
          }).toList(),
          underline: Container(
            height: 1,
            color: Theme.of(context).primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressTab() {
    final chartData = _prepareChartData();
    final inkastChartData = _prepareInkastChartData();
    final blastChartData = _prepareBlastChartData();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 8 Meter Progress Section
          Text(
            '8 Meter Progress',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          // Accuracy trend chart
          _buildAccuracyTrendChart(chartData),
          const SizedBox(height: 24),
          
          // Round-by-round accuracy
          _buildRoundAccuracyChart(chartData),
          const SizedBox(height: 24),
          
          // Performance zones
          _buildPerformanceZones(),
          const SizedBox(height: 32),
          
          // Inkasting Progress Section
          Text(
            'Inkasting Progress',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildPhaseDropdown(
            selectedPhase: _selectedInkastPhase,
            onChanged: (GamePhase phase) {
              setState(() {
                _selectedInkastPhase = phase;
              });
            },
            label: 'Filter by Phase',
          ),
          const SizedBox(height: 16),
          
          if (inkastChartData[GamePhase.early]!.isNotEmpty || 
              inkastChartData[GamePhase.mid]!.isNotEmpty || 
              inkastChartData[GamePhase.end]!.isNotEmpty) ...[
            _buildInkastOutOfBoundsChart(inkastChartData),
            const SizedBox(height: 24),
            _buildInkastPenaltyRatioChart(inkastChartData),
            const SizedBox(height: 24),
            _buildInkastNeighborRatioChart(inkastChartData),
            const SizedBox(height: 24),
            _buildInkastFirstThrowSuccessChart(inkastChartData),
          ] else
            _buildNoDataMessage('No Inkasting sessions yet. Start training to see progress!'),
          
          const SizedBox(height: 32),
          
          // Blasting Progress Section
          Text(
            'Blasting Progress',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildPhaseDropdown(
            selectedPhase: _selectedBlastPhase,
            onChanged: (GamePhase phase) {
              setState(() {
                _selectedBlastPhase = phase;
              });
            },
            label: 'Filter by Phase',
          ),
          const SizedBox(height: 16),
          
          if (blastChartData[GamePhase.early]!.isNotEmpty || 
              blastChartData[GamePhase.mid]!.isNotEmpty || 
              blastChartData[GamePhase.end]!.isNotEmpty) ...[
            _buildBlastAccuracyTrendChart(blastChartData),
            const SizedBox(height: 24),
            _buildBlastKubbsPerBatonChart(blastChartData),
            const SizedBox(height: 24),
            _buildBlastMissRateChart(blastChartData),
            const SizedBox(height: 24),
            _buildBlastHandicapChart(blastChartData),
          ] else
            _buildNoDataMessage('No Blasting sessions yet. Start training to see progress!'),
        ],
      ),
    );
  }

  // ==================== INKAST & BLAST TAB ====================

  Widget _buildInkastBlastTab() {
    final completedSessions = _allInkastBlastSessions
        .where((s) => s.isComplete)
        .toList();
    
    if (completedSessions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No Inkast & Blast sessions yet.\nStart training to see stats!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    final stats = _calculateInkastBlastStats(completedSessions);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inkast & Blast Training',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Overall Handicap Card
          _buildOverallHandicapCard(stats),
          const SizedBox(height: 24),

          // Lifetime vs Recent Handicap Comparison
          _buildHandicapComparisonCard(stats),
          const SizedBox(height: 24),

          // Comprehensive Performance Metrics
          _buildComprehensivePerformanceSection(completedSessions),
          const SizedBox(height: 24),

          // Per-Phase Statistics
          Text(
            'Statistics by Game Phase',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Early Game Phase
          if (stats.earlyPhaseStats.roundsCompleted > 0) ...[
            _buildPhaseStatsSection('Early Game (1-3 kubbs)', stats.earlyPhaseStats, Colors.green),
            const SizedBox(height: 16),
          ],

          // Mid Game Phase
          if (stats.midPhaseStats.roundsCompleted > 0) ...[
            _buildPhaseStatsSection('Mid Game (4-7 kubbs)', stats.midPhaseStats, Colors.blue),
            const SizedBox(height: 16),
          ],

          // End Game Phase
          if (stats.endPhaseStats.roundsCompleted > 0) ...[
            _buildPhaseStatsSection('End Game (8-10 kubbs)', stats.endPhaseStats, Colors.deepOrange),
            const SizedBox(height: 16),
          ],

          // Session Summary
          _buildInkastBlastSessionSummary(completedSessions),
        ],
      ),
    );
  }

  InkastBlastStatistics _calculateInkastBlastStats(List<InkastBlastSession> sessions) {
    // Separate sessions by recent (last 5) vs lifetime
    final recentSessions = sessions.take(5).toList();
    
    // Calculate lifetime handicap
    final lifetimeHandicap = _calculateHandicap(sessions);
    final recentHandicap = recentSessions.isNotEmpty ? _calculateHandicap(recentSessions) : lifetimeHandicap;

    // Calculate stats for each phase
    final earlyPhaseStats = _calculatePhaseStats(sessions, GamePhase.early);
    final midPhaseStats = _calculatePhaseStats(sessions, GamePhase.mid);
    final endPhaseStats = _calculatePhaseStats(sessions, GamePhase.end);

    return InkastBlastStatistics(
      lifetimeHandicap: lifetimeHandicap,
      recentHandicap: recentHandicap,
      totalSessions: sessions.length,
      totalRounds: sessions.fold(0, (sum, s) => sum + s.totalRounds),
      earlyPhaseStats: earlyPhaseStats,
      midPhaseStats: midPhaseStats,
      endPhaseStats: endPhaseStats,
    );
  }

  double _calculateHandicap(List<InkastBlastSession> sessions) {
    int totalPerformanceVsTarget = 0;
    int totalRounds = 0;

    for (final session in sessions) {
      for (final round in session.rounds) {
        totalPerformanceVsTarget += round.performanceVsTarget;
        totalRounds++;
      }
    }

    return totalRounds > 0 ? totalPerformanceVsTarget / totalRounds : 0.0;
  }

  PhaseStatistics _calculatePhaseStats(List<InkastBlastSession> sessions, GamePhase targetPhase) {
    int roundsCompleted = 0;
    int totalInkastKubbs = 0;
    int totalFirstCastInBounds = 0;
    int totalPenaltyKubbs = 0;
    int totalNeighborKubbs = 0;
    int totalFirstBatonKubbs = 0; // Kubbs hit with FIRST baton only
    int totalKubbsKnockedDown = 0;
    int totalBatonsUsed = 0;
    int totalPerformanceVsTarget = 0;

    for (final session in sessions) {
      for (final round in session.rounds) {
        // Determine if this round belongs to the target phase
        final roundPhase = _getRoundPhase(round.inkastKubbs);
        if (roundPhase != targetPhase) continue;

        roundsCompleted++;
        totalInkastKubbs += round.inkastKubbs;
        
        // First cast success: kubbs in bounds after first attempt
        final firstCastInBounds = round.inkastKubbs - round.kubbsOutFirstAttempt;
        totalFirstCastInBounds += firstCastInBounds;
        
        // Penalty kubbs: kubbs still out after second attempt
        totalPenaltyKubbs += round.penaltyKubbs;
        
        // Neighbor kubbs
        totalNeighborKubbs += round.neighborKubbs;
        
        // Initial Blast: kubbs hit with FIRST baton only
        if (round.batonThrows.isNotEmpty) {
          final firstThrow = round.batonThrows.first;
          if (firstThrow.isHit) {
            totalFirstBatonKubbs += firstThrow.kubbsHit;
          }
        }
        
        // Total kubbs knocked down and batons used
        totalKubbsKnockedDown += round.totalKubbsKnockedDown;
        totalBatonsUsed += round.batonsUsed;
        
        // Performance vs target
        totalPerformanceVsTarget += round.performanceVsTarget;
      }
    }

    return PhaseStatistics(
      roundsCompleted: roundsCompleted,
      firstCastSuccessRate: totalInkastKubbs > 0 ? totalFirstCastInBounds / totalInkastKubbs : 0.0,
      penaltyKubbRate: totalInkastKubbs > 0 ? totalPenaltyKubbs / totalInkastKubbs : 0.0,
      neighborRate: totalInkastKubbs > 0 ? totalNeighborKubbs / totalInkastKubbs : 0.0,
      avgInitialBlast: roundsCompleted > 0 ? totalFirstBatonKubbs / roundsCompleted : 0.0,
      kubbsPerBatonRatio: totalBatonsUsed > 0 ? totalKubbsKnockedDown / totalBatonsUsed : 0.0,
      handicap: roundsCompleted > 0 ? totalPerformanceVsTarget / roundsCompleted : 0.0,
    );
  }

  GamePhase _getRoundPhase(int inkastKubbs) {
    if (inkastKubbs >= 1 && inkastKubbs <= 3) return GamePhase.early;
    if (inkastKubbs >= 4 && inkastKubbs <= 7) return GamePhase.mid;
    if (inkastKubbs >= 8 && inkastKubbs <= 10) return GamePhase.end;
    return GamePhase.all;
  }

  Widget _buildOverallHandicapCard(InkastBlastStatistics stats) {
    final isPositive = stats.lifetimeHandicap >= 0;
    
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isPositive 
              ? [Colors.green.withValues(alpha: 0.15), Colors.green.withValues(alpha: 0.05)]
              : [Colors.red.withValues(alpha: 0.15), Colors.red.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isPositive ? Icons.trending_up : Icons.trending_down,
              size: 48,
              color: isPositive ? Colors.green : Colors.red,
            ),
            const SizedBox(height: 12),
            Text(
              'Lifetime Handicap',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${isPositive ? '+' : ''}${stats.lifetimeHandicap.toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPositive ? Colors.green : Colors.red,
                fontSize: 42,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Batons ${isPositive ? 'under' : 'over'} target on average',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      '${stats.totalSessions}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    Text(
                      'Sessions',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      '${stats.totalRounds}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepOrange,
                      ),
                    ),
                    Text(
                      'Rounds',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandicapComparisonCard(InkastBlastStatistics stats) {
    final difference = stats.recentHandicap - stats.lifetimeHandicap;
    final isImproving = difference >= 0;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isImproving ? Icons.trending_up : Icons.trending_down,
                  color: isImproving ? Colors.green : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Form',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Recent (Last 5)',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stats.recentHandicap >= 0 ? '+' : ''}${stats.recentHandicap.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isImproving ? Icons.arrow_forward : Icons.arrow_back,
                  color: isImproving ? Colors.green : Colors.orange,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Lifetime',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stats.lifetimeHandicap >= 0 ? '+' : ''}${stats.lifetimeHandicap.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                isImproving 
                  ? '${difference.abs().toStringAsFixed(2)} better than lifetime average! 🎉'
                  : '${difference.abs().toStringAsFixed(2)} below lifetime average',
                style: TextStyle(
                  color: isImproving ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComprehensivePerformanceSection(List<InkastBlastSession> sessions) {
    final recentSessions = sessions.take(5).toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Performance Metrics',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Inkasting Metrics
            Text(
              'Inkasting Performance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricComparison(
                    'Out of Bounds %',
                    _calculateLifetimeOutOfBounds(sessions),
                    _calculateRecentOutOfBounds(recentSessions),
                    '%',
                    reverse: true, // Lower is better
                    decimalPlaces: 1, // One decimal place
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricComparison(
                    'First Throw Clear',
                    _calculateLifetimeFirstThrowSuccess(sessions),
                    _calculateRecentFirstThrowSuccess(recentSessions),
                    '%',
                    decimalPlaces: 1, // One decimal place
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricComparison(
                    'Inkasts per Penalty',
                    _calculateLifetimeInkastsPerPenalty(sessions),
                    _calculateRecentInkastsPerPenalty(recentSessions),
                    '',
                    // Higher is better (default behavior)
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricComparison(
                    'Inkasts per Neighbor',
                    _calculateLifetimeInkastsPerNeighbor(sessions),
                    _calculateRecentInkastsPerNeighbor(recentSessions),
                    '',
                    reverse: true, // Lower is better
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Blasting Metrics
            Text(
              'Blasting Performance',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricComparison(
                    'Accuracy',
                    _calculateLifetimeBlastAccuracy(sessions),
                    _calculateRecentBlastAccuracy(recentSessions),
                    '%',
                    decimalPlaces: 1, // One decimal place
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricComparison(
                    'Kubbs per Baton',
                    _calculateLifetimeKubbsPerBaton(sessions),
                    _calculateRecentKubbsPerBaton(recentSessions),
                    '',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _buildMetricComparison(
                    'Miss Rate',
                    _calculateLifetimeMissRate(sessions),
                    _calculateRecentMissRate(recentSessions),
                    '%',
                    reverse: true, // Lower is better
                    decimalPlaces: 1, // One decimal place
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricComparison(
                    'Handicap',
                    _calculateLifetimeHandicap(sessions),
                    _calculateRecentHandicap(recentSessions),
                    '',
                    reverse: true, // Lower is better
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricComparison(String title, double lifetime, double recent, String unit, {bool reverse = false, int? decimalPlaces}) {
    final difference = recent - lifetime;
    final isImproving = reverse ? difference <= 0 : difference >= 0;
    final absDifference = difference.abs();
    
    // Determine decimal places for formatting
    int lifetimeDecimals = decimalPlaces ?? (unit == '%' ? 1 : 2);
    int recentDecimals = decimalPlaces ?? (unit == '%' ? 1 : 2);
    int differenceDecimals = decimalPlaces ?? (unit == '%' ? 1 : 2);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  Text(
                    '${recent.toStringAsFixed(recentDecimals)}$unit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue, // Changed from Colors.deepOrange to Colors.blue
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isImproving ? Icons.trending_up : Icons.trending_down,
              size: 16,
              color: isImproving ? Colors.green : Colors.red,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Lifetime',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
                  Text(
                    '${lifetime.toStringAsFixed(lifetimeDecimals)}$unit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700], // Keep lifetime as black
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '${absDifference.toStringAsFixed(differenceDecimals)}$unit ${isImproving ? 'better' : 'worse'}',
          style: TextStyle(
            fontSize: 10,
            color: isImproving ? Colors.green : Colors.red, // Keep trends as red/green
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseStatsSection(String title, PhaseStatistics stats, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  '${stats.roundsCompleted} rounds',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Handicap for this phase
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    stats.handicap >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Handicap: ${stats.handicap >= 0 ? '+' : ''}${stats.handicap.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Phase statistics grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildPhaseMetric(
                  '1st Cast Success',
                  '${(stats.firstCastSuccessRate * 100).toStringAsFixed(1)}%',
                  Icons.my_location,
                  Colors.blue,
                  'Percentage of kubbs in bounds after first inkast attempt',
                ),
                _buildPhaseMetric(
                  'Penalty Rate',
                  '${(stats.penaltyKubbRate * 100).toStringAsFixed(1)}%',
                  Icons.warning,
                  Colors.red,
                  'Percentage of inkasted kubbs still out after 2nd attempt',
                ),
                _buildPhaseMetric(
                  'Neighbor Rate',
                  '${(stats.neighborRate * 100).toStringAsFixed(1)}%',
                  Icons.people,
                  Colors.purple,
                  'Percentage of kubbs that land on top of other kubbs',
                ),
                _buildPhaseMetric(
                  'Initial Blast',
                  stats.avgInitialBlast.toStringAsFixed(2),
                  Icons.flash_on,
                  Colors.amber,
                  'Average number of kubbs hit with the FIRST baton',
                ),
                _buildPhaseMetric(
                  'Kubbs/Baton',
                  stats.kubbsPerBatonRatio.toStringAsFixed(2),
                  Icons.sports,
                  Colors.green,
                  'Average kubbs knocked down per baton thrown',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhaseMetric(String title, String value, IconData icon, Color color, String description) {
    return Card(
      color: Colors.grey[50],
      elevation: 1,
      child: InkWell(
        onTap: () => _showStatDescription(context, title, description),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInkastBlastSessionSummary(List<InkastBlastSession> sessions) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...sessions.take(5).map((session) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_formatDate(session.date)} - ${session.gamePhase.displayName}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    Text(
                      '${session.totalRounds} rounds',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays == 0) return 'Today';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.month}/${date.day}/${date.year}';
  }

  Widget _buildMetricsGrid(OverallStats stats) {
    final eightMeterSessions = _allSessions.where((s) => s.isComplete && (s.sessionType == SessionType.standard || s.sessionType == SessionType.aroundThePitch)).length;
    final inkastBlastSessions = _allInkastBlastSessions.where((s) => s.isComplete).length;
    
    return _buildSessionCountCard(
      'Total Sessions',
      eightMeterSessions,
      inkastBlastSessions,
      Icons.calendar_today,
    );
  }

  Widget _buildSessionCountCard(String title, int eightMeterSessions, int inkastBlastSessions, IconData icon) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          _showStatDescription(context, title, 'Breakdown of completed training sessions');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: Colors.blue, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$eightMeterSessions',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          '8 Meter',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$inkastBlastSessions',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Inkast/Blast',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange,
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
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color, String description) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () {
          _showStatDescription(context, title, description);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Icon(
                Icons.info_outline,
                size: 12,
                color: Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStatDescription(BuildContext context, String title, String description) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title),
            ),
          ],
        ),
        content: Text(description),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentFormCard(RecentFormStats stats) {
    final isImproving = stats.recentAvg > stats.overallAvg;
    final difference = ((stats.recentAvg - stats.overallAvg) * 100).abs();
    
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isImproving 
              ? [Colors.green.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.05)]
              : [Colors.orange.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isImproving ? Icons.trending_up : Icons.trending_flat,
                  color: isImproving ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Form - 8 Meters',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Last ${stats.sessionCount} sessions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFormMetric(
                  'Recent',
                  '${(stats.recentAvg * 100).toStringAsFixed(1)}%',
                  Colors.blue,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                _buildFormMetric(
                  'Overall',
                  '${(stats.overallAvg * 100).toStringAsFixed(1)}%',
                  Colors.grey,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                _buildFormMetric(
                  'Difference',
                  '${isImproving ? '+' : '-'}${difference.toStringAsFixed(1)}%',
                  isImproving ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
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

  Widget _buildInkastBlastRecentFormCard(RecentFormStats stats) {
    // For handicap, lower is better (like golf), so improvement means recentAvg < overallAvg
    final isImproving = stats.recentAvg < stats.overallAvg;
    final difference = (stats.recentAvg - stats.overallAvg).abs();
    
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isImproving 
              ? [Colors.green.withValues(alpha: 0.1), Colors.green.withValues(alpha: 0.05)]
              : [Colors.orange.withValues(alpha: 0.1), Colors.orange.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isImproving ? Icons.trending_up : Icons.trending_flat,
                  color: isImproving ? Colors.green : Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Form - Inkast/Blast',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Last ${stats.sessionCount} sessions',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFormMetric(
                  'Recent',
                  '${stats.recentAvg >= 0 ? '+' : ''}${stats.recentAvg.toStringAsFixed(1)}',
                  Colors.blue,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                _buildFormMetric(
                  'Overall',
                  '${stats.overallAvg >= 0 ? '+' : ''}${stats.overallAvg.toStringAsFixed(1)}',
                  Colors.grey,
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey[300],
                ),
                _buildFormMetric(
                  'Difference',
                  '${isImproving ? '+' : '-'}${difference.toStringAsFixed(1)}',
                  isImproving ? Colors.green : Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalRecordsSection(PersonalRecords records, InkastBlastPersonalRecords inkastBlastRecords, OverallStats stats) {
    return Column(
      children: [
        // 8 Meter Personal Records
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.blue, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      '8 Meter Records',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecordRow(
                  'Best Session Accuracy',
                  '${(records.bestSessionAccuracy * 100).toStringAsFixed(1)}%',
                  Icons.star,
                  Colors.amber,
                ),
                _buildRecordRow(
                  'Longest Streak',
                  '${records.longestStreak} hits',
                  Icons.local_fire_department,
                  Colors.orange,
                ),
                _buildRecordRow(
                  'Lifetime Perfect Rounds',
                  '${records.perfectRounds}',
                  Icons.stars,
                  Colors.purple,
                ),
                _buildRecordRow(
                  'Most Baseline Clears',
                  '${records.mostBaselineClears} in session',
                  Icons.military_tech,
                  Colors.green,
                ),
                _buildRecordRow(
                  'Best Around The Pitch Score',
                  '${records.bestAroundThePitchScore}',
                  Icons.flag,
                  Colors.teal,
                ),
                _buildRecordRow(
                  'Total 8 Meter Batons',
                  '${stats.totalBatons}',
                  Icons.sports,
                  Colors.green,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Inkast/Blast Personal Records
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.emoji_events, color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    Text(
                      'Inkast/Blast Records',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecordRow(
                  'Total Neighbors',
                  '${inkastBlastRecords.totalNeighbors}',
                  Icons.people,
                  Colors.brown,
                ),
                _buildRecordRow(
                  'Total A-Lines',
                  '${inkastBlastRecords.totalALines}',
                  Icons.warning,
                  Colors.red,
                ),
                _buildRecordRow(
                  'Overall Handicap - Early',
                  '${inkastBlastRecords.overallHandicapEarly >= 0 ? '+' : ''}${inkastBlastRecords.overallHandicapEarly.toStringAsFixed(1)}',
                  Icons.play_arrow,
                  Colors.green,
                ),
                _buildRecordRow(
                  'Overall Handicap - Mid',
                  '${inkastBlastRecords.overallHandicapMid >= 0 ? '+' : ''}${inkastBlastRecords.overallHandicapMid.toStringAsFixed(1)}',
                  Icons.pause,
                  Colors.blue,
                ),
                _buildRecordRow(
                  'Overall Handicap - End',
                  '${inkastBlastRecords.overallHandicapEnd >= 0 ? '+' : ''}${inkastBlastRecords.overallHandicapEnd.toStringAsFixed(1)}',
                  Icons.stop,
                  Colors.purple,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecordRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
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

  Widget _buildWeeklySummarySection(WeeklySummary summary) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Text(
                  'This Week',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Sessions',
                    '${summary.sessionsThisWeek}',
                    Icons.fitness_center,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Batons',
                    '${summary.batonsThisWeek}',
                    Icons.sports,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    'Accuracy',
                    '${(summary.accuracyThisWeek * 100).toStringAsFixed(1)}%',
                    Icons.gps_fixed,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSummaryCard(
                    'Baseline Clears',
                    '${summary.baselineClearsThisWeek}',
                    Icons.star,
                    Colors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
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
      ),
    );
  }



  Widget _buildRecentSessions() {
    final recentSessions = _allSessions
        .where((s) => s.isComplete)
        .take(5)
        .toList();

    if (recentSessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.sports,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No completed sessions yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start practicing to see your progress here!',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Sessions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...recentSessions.map((session) => _buildSessionTile(session)),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(PracticeSession session) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getAccuracyColor(session.accuracy),
        child: Text(
          '${(session.accuracy * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
      title: Text('${session.totalBatons} batons • ${session.totalKubbs} hits'),
      subtitle: Text(
        '${session.date.day}/${session.date.month}/${session.date.year}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${session.completedRounds.length} rounds',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (session.totalBaselineClears > 0)
            Icon(Icons.star, color: Colors.amber, size: 16),
        ],
      ),
    );
  }


  Widget _buildLengthMetric(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
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
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAccuracyTrendChart(List<ChartDataPoint> chartData) {
    if (chartData.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                'No data for trend analysis',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accuracy Trend',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value * 100).toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < chartData.length) {
                            return Text(
                              '${value.toInt() + 1}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedSpots) {
                        return touchedSpots.map((LineBarSpot touchedSpot) {
                          // Skip tooltip for the target line (index 1)
                          if (touchedSpot.barIndex == 1) {
                            return null;
                          }
                          
                          final sessionIndex = touchedSpot.x.toInt();
                          if (sessionIndex >= 0 && sessionIndex < chartData.length) {
                            final dataPoint = chartData[sessionIndex];
                            final dateStr = '${dataPoint.date.month}/${dataPoint.date.day}/${dataPoint.date.year}';
                            final accuracy = (touchedSpot.y * 100).toStringAsFixed(1);
                            
                            return LineTooltipItem(
                              'Session ${sessionIndex + 1}\n$dateStr\nAccuracy: $accuracy%\n${dataPoint.kubbs}/${dataPoint.batons} hits',
                              const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            );
                          }
                          return null;
                        }).toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: chartData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value.accuracy);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: Colors.blue,
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    // Target line at 50%
                    LineChartBarData(
                      spots: [
                        FlSpot(0, 0.5),
                        FlSpot(chartData.length.toDouble() - 1, 0.5),
                      ],
                      isCurved: false,
                      color: Colors.orange.withValues(alpha: 0.7),
                      barWidth: 2,
                      dotData: FlDotData(show: false),
                      dashArray: [5, 5],
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

  Widget _buildRoundAccuracyChart(List<ChartDataPoint> chartData) {
    // Group data by round position (1st round, 2nd round, etc.)
    final roundData = <int, List<double>>{};
    
    for (final session in _allSessions.where((s) => s.isComplete)) {
      for (int i = 0; i < session.completedRounds.length; i++) {
        final round = session.completedRounds[i];
        roundData.putIfAbsent(i + 1, () => []).add(round.accuracy);
      }
    }

    if (roundData.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round Position Analysis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.0,
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${(value * 100).toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'R${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final roundNumber = group.x.toInt();
                        final roundAccuracies = roundData[roundNumber] ?? [];
                        final avgAccuracy = roundAccuracies.isEmpty 
                            ? 0.0 
                            : roundAccuracies.reduce((a, b) => a + b) / roundAccuracies.length;
                        final sessionCount = roundAccuracies.length;
                        
                        return BarTooltipItem(
                          'Round $roundNumber\nAvg: ${(avgAccuracy * 100).toStringAsFixed(1)}%\nSessions: $sessionCount',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  barGroups: roundData.entries.map((entry) {
                    final avgAccuracy = entry.value.reduce((a, b) => a + b) / entry.value.length;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: avgAccuracy,
                          color: _getAccuracyColor(avgAccuracy),
                          width: 20,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceZones() {
    final zones = _calculatePerformanceZones();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Text(
            'Performance Zones',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Number of sessions in each accuracy range',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildZoneCard(
                    'Excellent',
                    '${zones.excellent}',
                    Colors.green,
                    '90%+ accuracy',
                  ),
                ),
                Expanded(
                  child: _buildZoneCard(
                    'Good',
                    '${zones.good}',
                    Colors.blue,
                    '70-89% accuracy',
                  ),
                ),
                Expanded(
                  child: _buildZoneCard(
                    'Average',
                    '${zones.average}',
                    Colors.orange,
                    '50-69% accuracy',
                  ),
                ),
                Expanded(
                  child: _buildZoneCard(
                    'Needs Work',
                    '${zones.needsWork}',
                    Colors.red,
                    '<50% accuracy',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCard(String title, String count, Color color, String description) {
    return Container(
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            count,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            description,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Data calculation methods
  OverallStats _calculateOverallStats() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    return OverallStats(
      totalSessions: completedSessions.length,
      totalBatons: completedSessions.fold(0, (sum, s) => sum + s.totalBatons),
      totalKubbs: completedSessions.fold(0, (sum, s) => sum + s.totalKubbs),
      overallAccuracy: completedSessions.isEmpty ? 0.0 : 
        completedSessions.fold(0.0, (sum, s) => sum + s.accuracy) / completedSessions.length,
      bestStreak: _calculateBestStreak(),
    );
  }


  int _calculateBestStreak() {
    int maxStreak = 0;
    int currentStreak = 0;
    
    for (final session in _allSessions.where((s) => s.isComplete)) {
      for (final round in session.completedRounds) {
        for (final throw_ in round.batonThrows) {
          if (throw_.isHit) {
            currentStreak++;
            maxStreak = maxStreak > currentStreak ? maxStreak : currentStreak;
          } else {
            currentStreak = 0;
          }
        }
      }
    }
    
    return maxStreak;
  }


  List<ChartDataPoint> _prepareChartData() {
    final dataPoints = <ChartDataPoint>[];
    
    for (final session in _allSessions.where((s) => s.isComplete)) {
      dataPoints.add(ChartDataPoint(
        date: session.date,
        accuracy: session.accuracy,
        kubbs: session.totalKubbs,
        batons: session.totalBatons,
      ));
    }
    
    return dataPoints;
  }

  PerformanceZones _calculatePerformanceZones() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    int excellent = 0, good = 0, average = 0, needsWork = 0;
    
    for (final session in completedSessions) {
      final accuracy = session.accuracy;
      if (accuracy >= 0.9) {
        excellent++;
      } else if (accuracy >= 0.7) {
        good++;
      } else if (accuracy >= 0.5) {
        average++;
      } else {
        needsWork++;
      }
    }
    
    return PerformanceZones(
      excellent: excellent,
      good: good,
      average: average,
      needsWork: needsWork,
    );
  }

  RecentFormStats _calculateRecentForm() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    if (completedSessions.isEmpty) {
      return RecentFormStats(
        recentAvg: 0.0,
        overallAvg: 0.0,
        sessionCount: 0,
      );
    }
    
    final sessionCount = completedSessions.length >= 5 ? 5 : completedSessions.length;
    final recentSessions = completedSessions.take(sessionCount).toList();
    
    final recentAvg = recentSessions.isEmpty 
        ? 0.0 
        : recentSessions.fold(0.0, (sum, s) => sum + s.accuracy) / recentSessions.length;
    
    final overallAvg = completedSessions.fold(0.0, (sum, s) => sum + s.accuracy) / completedSessions.length;
    
    return RecentFormStats(
      recentAvg: recentAvg,
      overallAvg: overallAvg,
      sessionCount: sessionCount,
    );
  }

  RecentFormStats _calculateInkastBlastRecentForm() {
    final completedSessions = _allInkastBlastSessions.where((s) => s.isComplete).toList();
    
    if (completedSessions.isEmpty) {
      return RecentFormStats(
        recentAvg: 0.0,
        overallAvg: 0.0,
        sessionCount: 0,
      );
    }
    
    final sessionCount = completedSessions.length >= 5 ? 5 : completedSessions.length;
    final recentSessions = completedSessions.take(sessionCount).toList();
    
    final recentHandicap = recentSessions.isEmpty 
        ? 0.0 
        : _calculateHandicap(recentSessions);
    
    final overallHandicap = _calculateHandicap(completedSessions);
    
    return RecentFormStats(
      recentAvg: recentHandicap,
      overallAvg: overallHandicap,
      sessionCount: sessionCount,
    );
  }

  PersonalRecords _calculatePersonalRecords() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    if (completedSessions.isEmpty) {
      return PersonalRecords(
        bestSessionAccuracy: 0.0,
        longestStreak: 0,
        perfectRounds: 0,
        mostBaselineClears: 0,
        bestAroundThePitchScore: 0,
      );
    }
    
    double bestSessionAccuracy = 0.0;
    int longestStreak = 0;
    int perfectRounds = 0;
    int mostBaselineClears = 0;
    
    int currentStreak = 0;
    
    for (final session in completedSessions) {
      // Best session accuracy
      if (session.accuracy > bestSessionAccuracy) {
        bestSessionAccuracy = session.accuracy;
      }
      
      // Most baseline clears
      if (session.totalBaselineClears > mostBaselineClears) {
        mostBaselineClears = session.totalBaselineClears;
      }
      
      // Longest streak and perfect rounds
      for (final round in session.completedRounds) {
        if (round.hits == 6 && round.totalBatonThrows == 6) {
          perfectRounds++;
        }
        
        for (final throw_ in round.batonThrows) {
          if (throw_.isHit) {
            currentStreak++;
            if (currentStreak > longestStreak) {
              longestStreak = currentStreak;
            }
          } else {
            currentStreak = 0;
          }
        }
      }
    }
    
    // Calculate best Around the Pitch score
    int bestAroundThePitchScore = 0;
    for (final session in completedSessions) {
      if (session.sessionType == SessionType.aroundThePitch) {
        // Around the Pitch score is typically total kubbs hit
        final sessionScore = session.totalKubbs;
        if (sessionScore > bestAroundThePitchScore) {
          bestAroundThePitchScore = sessionScore;
        }
      }
    }

    return PersonalRecords(
      bestSessionAccuracy: bestSessionAccuracy,
      longestStreak: longestStreak,
      perfectRounds: perfectRounds,
      mostBaselineClears: mostBaselineClears,
      bestAroundThePitchScore: bestAroundThePitchScore,
    );
  }

  InkastBlastPersonalRecords _calculateInkastBlastPersonalRecords() {
    final completedSessions = _allInkastBlastSessions.where((s) => s.isComplete).toList();
    
    if (completedSessions.isEmpty) {
      return InkastBlastPersonalRecords(
        totalNeighbors: 0,
        totalALines: 0,
        overallHandicapEarly: 0.0,
        overallHandicapMid: 0.0,
        overallHandicapEnd: 0.0,
      );
    }

    int totalNeighbors = 0;
    int totalALines = 0;
    
    // Calculate totals
    for (final session in completedSessions) {
      totalNeighbors += session.totalNeighborKubbs;
      // A-Lines are rounds where inkasted kubbs are not cleared in 6 or fewer batons
      totalALines += session.rounds.where((round) => round.batonsUsed > 6).length;
    }

    // Calculate handicap by phase
    final earlyPhaseSessions = completedSessions.where((s) => s.gamePhase == GamePhase.early).toList();
    final midPhaseSessions = completedSessions.where((s) => s.gamePhase == GamePhase.mid).toList();
    final endPhaseSessions = completedSessions.where((s) => s.gamePhase == GamePhase.end).toList();

    final overallHandicapEarly = earlyPhaseSessions.isNotEmpty ? _calculateHandicap(earlyPhaseSessions) : 0.0;
    final overallHandicapMid = midPhaseSessions.isNotEmpty ? _calculateHandicap(midPhaseSessions) : 0.0;
    final overallHandicapEnd = endPhaseSessions.isNotEmpty ? _calculateHandicap(endPhaseSessions) : 0.0;

    return InkastBlastPersonalRecords(
      totalNeighbors: totalNeighbors,
      totalALines: totalALines,
      overallHandicapEarly: overallHandicapEarly,
      overallHandicapMid: overallHandicapMid,
      overallHandicapEnd: overallHandicapEnd,
    );
  }

  WeeklySummary _calculateWeeklySummary() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekStartDate = DateTime(weekStart.year, weekStart.month, weekStart.day);
    
    final weekSessions = _allSessions.where((s) => 
      s.isComplete && s.date.isAfter(weekStartDate)
    ).toList();
    
    if (weekSessions.isEmpty) {
      return WeeklySummary(
        sessionsThisWeek: 0,
        batonsThisWeek: 0,
        accuracyThisWeek: 0.0,
        baselineClearsThisWeek: 0,
      );
    }
    
    final totalBatons = weekSessions.fold(0, (sum, s) => sum + s.totalBatons);
    final totalHits = weekSessions.fold(0, (sum, s) => sum + s.totalKubbs);
    final accuracy = totalBatons > 0 ? totalHits / totalBatons : 0.0;
    final baselineClears = weekSessions.fold(0, (sum, s) => sum + s.totalBaselineClears);
    
    return WeeklySummary(
      sessionsThisWeek: weekSessions.length,
      batonsThisWeek: totalBatons,
      accuracyThisWeek: accuracy,
      baselineClearsThisWeek: baselineClears,
    );
  }

  AdvancedTrainingStats _calculateAdvancedTrainingStatsForSessions(List<PracticeSession> sessions) {
    if (sessions.isEmpty) {
      return AdvancedTrainingStats(
        firstThrowAccuracy: 0.0,
        consistencyScore: 0.0,
        clutchAccuracy: 0.0,
        avgKubbsPerRound: 0.0,
      );
    }
    
    // First throw accuracy
    int firstThrows = 0;
    int firstThrowHits = 0;
    
    // Clutch performance (3-4 kubbs down)
    int clutchThrows = 0;
    int clutchHits = 0;
    
    // Average kubbs per round
    int totalRounds = 0;
    int totalKubbsKnocked = 0;
    
    for (final session in sessions) {
      for (final round in session.completedRounds) {
        totalRounds++;
        totalKubbsKnocked += round.hits;
        
        // First throw of each round
        if (round.batonThrows.isNotEmpty) {
          firstThrows++;
          if (round.batonThrows.first.isHit) {
            firstThrowHits++;
          }
        }
        
        // Clutch performance (throws after 3-4 hits)
        int hitsInRound = 0;
        for (final throw_ in round.batonThrows) {
          if (hitsInRound >= 3 && hitsInRound <= 4) {
            clutchThrows++;
            if (throw_.isHit) {
              clutchHits++;
            }
          }
          if (throw_.isHit) {
            hitsInRound++;
          }
        }
      }
    }
    
    final firstThrowAccuracy = firstThrows > 0 ? firstThrowHits / firstThrows : 0.0;
    final clutchAccuracy = clutchThrows > 0 ? clutchHits / clutchThrows : 0.0;
    final avgKubbsPerRound = totalRounds > 0 ? totalKubbsKnocked / totalRounds : 0.0;
    
    // Consistency score (inverse of standard deviation, normalized)
    double consistencyScore = 0.0;
    if (sessions.length > 1) {
      final accuracies = sessions.map((s) => s.accuracy).toList();
      final mean = accuracies.reduce((a, b) => a + b) / accuracies.length;
      final variance = accuracies.map((a) => (a - mean) * (a - mean)).reduce((a, b) => a + b) / accuracies.length;
      final stdDev = variance > 0 ? 1.0 / (1.0 + variance) : 1.0;
      consistencyScore = stdDev;
    }
    
    return AdvancedTrainingStats(
      firstThrowAccuracy: firstThrowAccuracy,
      consistencyScore: consistencyScore,
      clutchAccuracy: clutchAccuracy,
      avgKubbsPerRound: avgKubbsPerRound,
    );
  }

  int _calculateLongestStreakForSessions(List<PracticeSession> sessions) {
    int longestStreak = 0;
    
    for (final session in sessions) {
      int currentStreak = 0;
      int maxStreakInSession = 0;
      
      for (final round in session.completedRounds) {
        if (round.hasBaselineClear) {
          currentStreak++;
          maxStreakInSession = currentStreak > maxStreakInSession ? currentStreak : maxStreakInSession;
        } else {
          currentStreak = 0;
        }
      }
      
      longestStreak = maxStreakInSession > longestStreak ? maxStreakInSession : longestStreak;
    }
    
    return longestStreak;
  }

  int _calculateAroundPitchLongestStreak(List<PracticeSession> sessions) {
    if (sessions.isEmpty) return 0;
    
    int longestStreak = 0;
    
    for (final session in sessions) {
      // Only process completed sessions
      if (!session.isComplete || session.completedRounds.isEmpty) continue;
      
      final round = session.completedRounds.first; // Around the pitch has only one round
      int currentStreak = 0;
      int maxStreakInSession = 0;
      
      for (final throw_ in round.batonThrows) {
        if (throw_.isHit) {
          currentStreak++;
          maxStreakInSession = currentStreak > maxStreakInSession ? currentStreak : maxStreakInSession;
        } else {
          currentStreak = 0;
        }
      }
      
      longestStreak = maxStreakInSession > longestStreak ? maxStreakInSession : longestStreak;
    }
    
    return longestStreak;
  }

  double _calculateAroundPitchClutchPerformance(List<PracticeSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    
    int clutchThrows = 0;
    int clutchHits = 0;
    
    for (final session in sessions) {
      // Only process completed sessions
      if (!session.isComplete || session.completedRounds.isEmpty) continue;
      
      final round = session.completedRounds.first; // Around the pitch has only one round
      final targetScore = session.targetScore;
      
      for (int i = 0; i < round.batonThrows.length; i++) {
        final throw_ = round.batonThrows[i];
        final throwsUsed = i + 1;
        final kubbsDown = round.hits;
        final kubbsRemaining = 10 - kubbsDown;
        final kingRemaining = 1; // Assuming king is still up at this point
        final piecesRemaining = kubbsRemaining + kingRemaining;
        final throwsRemaining = targetScore - throwsUsed;
        
        // Calculate buffer: extra throws beyond what's needed (if perfect)
        final buffer = throwsRemaining - piecesRemaining;
        
        // Check if this throw was made during a warning state (yellow or red)
        // Yellow: buffer 2-4, Red: buffer <= 1
        if (buffer >= 1 && buffer <= 4) {
          clutchThrows++;
          if (throw_.isHit) {
            clutchHits++;
          }
        }
      }
    }
    
    return clutchThrows > 0 ? clutchHits / clutchThrows : 0.0;
  }

  // ==================== CHART DATA PREPARATION ====================

  Map<GamePhase, List<InkastChartDataPoint>> _prepareInkastChartData() {
    final inkastSessions = _allInkastBlastSessions
        .where((s) => s.isComplete)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final Map<GamePhase, List<InkastChartDataPoint>> phaseData = {
      GamePhase.early: [],
      GamePhase.mid: [],
      GamePhase.end: [],
    };
    
    for (final session in inkastSessions) {
      // Group rounds by their individual phases based on kubbs to inkast
      final Map<GamePhase, List<InkastBlastRound>> roundsByPhase = {
        GamePhase.early: [],
        GamePhase.mid: [],
        GamePhase.end: [],
      };
      
      for (final round in session.rounds) {
        final roundPhase = _getRoundPhase(round.inkastKubbs);
        if (roundPhase != GamePhase.all) {
          roundsByPhase[roundPhase]!.add(round);
        }
      }
      
      // Create data points for each phase that has rounds
      for (final phase in [GamePhase.early, GamePhase.mid, GamePhase.end]) {
        final roundsForPhase = roundsByPhase[phase]!;
        if (roundsForPhase.isNotEmpty) {
          final dataPoint = InkastChartDataPoint(
            date: session.date,
            handicap: _calculateInkastHandicapForPhase(roundsForPhase),
            accuracy: _calculateInkastAccuracyForPhase(roundsForPhase),
            efficiency: _calculateEfficiencyForPhase(roundsForPhase),
            firstThrowSuccessRate: _calculateFirstThrowSuccessRateForPhase(roundsForPhase),
            penaltyRate: _calculatePenaltyRateForPhase(roundsForPhase),
            outOfBoundsPercentage: _calculateOutOfBoundsPercentageForPhase(roundsForPhase),
            inkastsPerPenaltyRatio: _calculateInkastsPerPenaltyRatioForPhase(roundsForPhase),
            inkastsPerNeighborRatio: _calculateInkastsPerNeighborRatioForPhase(roundsForPhase),
          );
          
          // Add to appropriate phase bucket based on filter
          if (_selectedInkastPhase == GamePhase.all || _selectedInkastPhase == phase) {
            phaseData[phase]!.add(dataPoint);
          }
        }
      }
    }
    
    return phaseData;
  }

  Map<GamePhase, List<BlastChartDataPoint>> _prepareBlastChartData() {
    final blastSessions = _allInkastBlastSessions
        .where((s) => s.isComplete)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    
    final Map<GamePhase, List<BlastChartDataPoint>> phaseData = {
      GamePhase.early: [],
      GamePhase.mid: [],
      GamePhase.end: [],
    };
    
    for (final session in blastSessions) {
      // Group rounds by their individual phases based on kubbs to inkast
      final Map<GamePhase, List<InkastBlastRound>> roundsByPhase = {
        GamePhase.early: [],
        GamePhase.mid: [],
        GamePhase.end: [],
      };
      
      for (final round in session.rounds) {
        final roundPhase = _getRoundPhase(round.inkastKubbs);
        if (roundPhase != GamePhase.all) {
          roundsByPhase[roundPhase]!.add(round);
        }
      }
      
      // Create data points for each phase that has rounds
      for (final phase in [GamePhase.early, GamePhase.mid, GamePhase.end]) {
        final roundsForPhase = roundsByPhase[phase]!;
        if (roundsForPhase.isNotEmpty) {
          final dataPoint = BlastChartDataPoint(
            date: session.date,
            accuracy: _calculateBlastAccuracyForPhase(roundsForPhase),
            efficiency: _calculateEfficiencyForPhase(roundsForPhase),
            missRate: _calculateBlastMissRateForPhase(roundsForPhase),
            averageKubbsPerBaton: _calculateEfficiencyForPhase(roundsForPhase),
            handicap: _calculateBlastHandicapForPhase(roundsForPhase),
          );
          
          // Add to appropriate phase bucket based on filter
          if (_selectedBlastPhase == GamePhase.all || _selectedBlastPhase == phase) {
            phaseData[phase]!.add(dataPoint);
          }
        }
      }
    }
    
    return phaseData;
  }


  // ==================== PHASE-SPECIFIC CALCULATIONS ====================

  // Helper methods for calculating metrics by phase (list of rounds)
  double _calculateInkastHandicapForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final efficiency = _calculateEfficiencyForPhase(rounds);
    return (1.0 - efficiency).clamp(0.0, 1.0);
  }

  double _calculateInkastAccuracyForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalBatons = rounds.fold(0, (sum, r) => sum + r.batonsUsed);
    final totalHits = rounds.fold(0, (sum, r) => sum + r.totalKubbsKnockedDown);
    return totalBatons > 0 ? totalHits / totalBatons : 0.0;
  }

  double _calculateEfficiencyForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalKubbs = rounds.fold(0, (sum, r) => sum + r.totalKubbsKnockedDown);
    final totalBatons = rounds.fold(0, (sum, r) => sum + r.batonsUsed);
    return totalBatons > 0 ? totalKubbs / totalBatons : 0.0;
  }

  double _calculateFirstThrowSuccessRateForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalInkastKubbs = rounds.fold(0, (sum, r) => sum + r.inkastKubbs);
    final totalClearedFirstThrow = rounds.fold(0, (sum, r) => sum + r.kubbsClearedFirstThrow);
    return totalInkastKubbs > 0 ? totalClearedFirstThrow / totalInkastKubbs : 0.0;
  }

  double _calculatePenaltyRateForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalInkastKubbs = rounds.fold(0, (sum, r) => sum + r.inkastKubbs);
    final totalPenaltyKubbs = rounds.fold(0, (sum, r) => sum + r.penaltyKubbs);
    return totalInkastKubbs > 0 ? totalPenaltyKubbs / totalInkastKubbs : 0.0;
  }

  double _calculateOutOfBoundsPercentageForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalOutOfBounds = rounds.fold(0, (sum, r) => sum + r.kubbsOutFirstAttempt + r.kubbsOutSecondAttempt);
    final totalInkastAttempts = rounds.fold(0, (sum, r) => sum + r.inkastKubbs + r.kubbsOutFirstAttempt + r.kubbsOutSecondAttempt);
    return totalInkastAttempts > 0 ? totalOutOfBounds / totalInkastAttempts : 0.0;
  }

  double _calculateInkastsPerPenaltyRatioForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalInkasts = rounds.fold(0, (sum, r) => sum + r.inkastKubbs);
    final totalPenaltyKubbs = rounds.fold(0, (sum, r) => sum + r.penaltyKubbs);
    return totalPenaltyKubbs > 0 ? totalInkasts / totalPenaltyKubbs : totalInkasts.toDouble();
  }

  double _calculateInkastsPerNeighborRatioForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalInkasts = rounds.fold(0, (sum, r) => sum + r.inkastKubbs);
    final totalNeighborKubbs = rounds.fold(0, (sum, r) => sum + r.neighborKubbs);
    return totalNeighborKubbs > 0 ? totalInkasts / totalNeighborKubbs : totalInkasts.toDouble();
  }

  double _calculateBlastAccuracyForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalBatons = rounds.fold(0, (sum, r) => sum + r.batonsUsed);
    final totalMisses = rounds.fold(0, (sum, r) => sum + r.misses);
    final totalHits = totalBatons - totalMisses;
    return totalBatons > 0 ? totalHits / totalBatons : 0.0;
  }

  double _calculateBlastMissRateForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final totalBatons = rounds.fold(0, (sum, r) => sum + r.batonsUsed);
    final totalMisses = rounds.fold(0, (sum, r) => sum + r.misses);
    return totalBatons > 0 ? totalMisses / totalBatons : 0.0;
  }

  double _calculateBlastHandicapForPhase(List<InkastBlastRound> rounds) {
    if (rounds.isEmpty) return 0.0;
    final efficiency = _calculateEfficiencyForPhase(rounds);
    return (1.0 - efficiency).clamp(0.0, 1.0);
  }

  // ==================== PROGRESS CHART BUILDERS ====================

  List<DateTime> _getAllDatesFromPhaseData(Map<GamePhase, List<dynamic>> data) {
    final allDates = <DateTime>[];
    for (final phaseData in data.values) {
      for (final point in phaseData) {
        if (point.date is DateTime && !allDates.contains(point.date)) {
          allDates.add(point.date);
        }
      }
    }
    allDates.sort((a, b) => a.compareTo(b));
    return allDates;
  }

  List<FlSpot> _calculateSpotsForPhase<T>(List<T> phaseData, double Function(T) valueExtractor, List<DateTime> allDates) {
    final spots = <FlSpot>[];
    for (int i = 0; i < phaseData.length; i++) {
      final point = phaseData[i];
      final date = (point as dynamic).date as DateTime?;
      if (date != null) {
        final xIndex = allDates.indexOf(date);
        if (xIndex >= 0) {
          spots.add(FlSpot(xIndex.toDouble(), valueExtractor(point)));
        }
      }
    }
    return spots;
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNoDataMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }

  // Helper method to build lineBarsData for inkast charts
  List<LineChartBarData> _buildInkastLineBarsData<T>(
    Map<GamePhase, List<T>> data, 
    double Function(T) valueExtractor, 
    List<DateTime> allDates
  ) {
    final lineBarsData = <LineChartBarData>[];
    
    if (_selectedInkastPhase == GamePhase.all) {
      // Show all phases with different colors
      if (data[GamePhase.early]!.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: _calculateSpotsForPhase(data[GamePhase.early]!, valueExtractor, allDates),
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        );
      }
      if (data[GamePhase.mid]!.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: _calculateSpotsForPhase(data[GamePhase.mid]!, valueExtractor, allDates),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        );
      }
      if (data[GamePhase.end]!.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: _calculateSpotsForPhase(data[GamePhase.end]!, valueExtractor, allDates),
            isCurved: true,
            color: Colors.deepOrange,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        );
      }
    } else {
      // Show single line for selected phase
      if (data[_selectedInkastPhase]!.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: _calculateSpotsForPhase(data[_selectedInkastPhase]!, valueExtractor, allDates),
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        );
      }
    }
    
    return lineBarsData;
  }

  // Helper method to build lineBarsData for blast charts
  List<LineChartBarData> _buildBlastLineBarsData<T>(
    Map<GamePhase, List<T>> data, 
    double Function(T) valueExtractor, 
    List<DateTime> allDates
  ) {
    final lineBarsData = <LineChartBarData>[];
    
    if (_selectedBlastPhase == GamePhase.all) {
      // Show all phases with different colors
      if (data[GamePhase.early]!.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: _calculateSpotsForPhase(data[GamePhase.early]!, valueExtractor, allDates),
            isCurved: true,
            color: Colors.green,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        );
      }
      if (data[GamePhase.mid]!.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: _calculateSpotsForPhase(data[GamePhase.mid]!, valueExtractor, allDates),
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        );
      }
      if (data[GamePhase.end]!.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: _calculateSpotsForPhase(data[GamePhase.end]!, valueExtractor, allDates),
            isCurved: true,
            color: Colors.deepOrange,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        );
      }
    } else {
      // Show single line for selected phase
      if (data[_selectedBlastPhase]!.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: _calculateSpotsForPhase(data[_selectedBlastPhase]!, valueExtractor, allDates),
            isCurved: true,
            color: Theme.of(context).primaryColor,
            barWidth: 3,
            dotData: FlDotData(show: true),
          ),
        );
      }
    }
    
    return lineBarsData;
  }

  // Helper method to build legend for inkast charts
  Widget _buildInkastLegend() {
    if (_selectedInkastPhase == GamePhase.all) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Early', Colors.green),
          const SizedBox(width: 16),
          _buildLegendItem('Mid', Colors.blue),
          const SizedBox(width: 16),
          _buildLegendItem('Late', Colors.deepOrange),
        ],
      );
    } else {
      // No legend needed for single line charts
      return const SizedBox.shrink();
    }
  }

  // Helper method to build legend for blast charts
  Widget _buildBlastLegend() {
    if (_selectedBlastPhase == GamePhase.all) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem('Early', Colors.green),
          const SizedBox(width: 16),
          _buildLegendItem('Mid', Colors.blue),
          const SizedBox(width: 16),
          _buildLegendItem('Late', Colors.deepOrange),
        ],
      );
    } else {
      // No legend needed for single line charts
      return const SizedBox.shrink();
    }
  }

  Widget _buildInkastOutOfBoundsChart(Map<GamePhase, List<InkastChartDataPoint>> data) {
    final allDates = _getAllDatesFromPhaseData(data);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Out of Bounds %',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final allDates = _getAllDatesFromPhaseData(data);
                          if (value.toInt() < allDates.length) {
                            return Text(
                              '${allDates[value.toInt()].month}/${allDates[value.toInt()].day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildInkastLineBarsData(data, (point) => point.outOfBoundsPercentage * 100, allDates),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Legend based on filter
            _buildInkastLegend(),
            const SizedBox(height: 8),
            
            Text(
              'Percentage of inkasted kubbs that land out of bounds (lower is better)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInkastPenaltyRatioChart(Map<GamePhase, List<InkastChartDataPoint>> data) {
    final allDates = _getAllDatesFromPhaseData(data);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inkasts per Penalty Ratio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < allDates.length) {
                            return Text(
                              '${allDates[value.toInt()].month}/${allDates[value.toInt()].day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildInkastLineBarsData(data, (point) => point.inkastsPerPenaltyRatio, allDates),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Legend based on filter
            _buildInkastLegend(),
            const SizedBox(height: 8),
            
            Text(
              'Required inkasts divided by total penalties (higher is better)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInkastNeighborRatioChart(Map<GamePhase, List<InkastChartDataPoint>> data) {
    final allDates = _getAllDatesFromPhaseData(data);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inkasts per Neighbor Ratio',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < allDates.length) {
                            return Text(
                              '${allDates[value.toInt()].month}/${allDates[value.toInt()].day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildInkastLineBarsData(data, (point) => point.inkastsPerNeighborRatio, allDates),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Legend based on filter
            _buildInkastLegend(),
            const SizedBox(height: 8),
            
            Text(
              'Required inkasts divided by total neighbors (higher is better)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInkastFirstThrowSuccessChart(Map<GamePhase, List<InkastChartDataPoint>> data) {
    final allDates = _getAllDatesFromPhaseData(data);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'First Throw Clear Rate',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < allDates.length) {
                            return Text(
                              '${allDates[value.toInt()].month}/${allDates[value.toInt()].day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildInkastLineBarsData(data, (point) => point.firstThrowSuccessRate * 100, allDates),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Legend based on filter
            _buildInkastLegend(),
            const SizedBox(height: 8),
            
            Text(
              'Percentage of kubbs cleared on first throw attempt',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlastAccuracyTrendChart(Map<GamePhase, List<BlastChartDataPoint>> data) {
    final allDates = _getAllDatesFromPhaseData(data);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Blast Accuracy',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < allDates.length) {
                            return Text(
                              '${allDates[value.toInt()].month}/${allDates[value.toInt()].day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildBlastLineBarsData(data, (point) => point.accuracy * 100, allDates),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Legend based on filter
            _buildBlastLegend(),
            const SizedBox(height: 8),
            
            Text(
              'Percentage of batons that hit any target (regardless of kubbs hit)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlastKubbsPerBatonChart(Map<GamePhase, List<BlastChartDataPoint>> data) {
    final allDates = _getAllDatesFromPhaseData(data);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kubbs per Baton',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final allDates = _getAllDatesFromPhaseData(data);
                          if (value.toInt() < allDates.length) {
                            return Text(
                              '${allDates[value.toInt()].month}/${allDates[value.toInt()].day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildBlastLineBarsData(data, (point) => point.efficiency, allDates),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Legend based on filter
            _buildBlastLegend(),
            const SizedBox(height: 8),
            
            Text(
              'Average number of kubbs knocked down per baton',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlastMissRateChart(Map<GamePhase, List<BlastChartDataPoint>> data) {
    final allDates = _getAllDatesFromPhaseData(data);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Miss Rate Analysis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < allDates.length) {
                            return Text(
                              '${allDates[value.toInt()].month}/${allDates[value.toInt()].day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildBlastLineBarsData(data, (point) => point.missRate * 100, allDates),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Legend based on filter
            _buildBlastLegend(),
            const SizedBox(height: 8),
            
            Text(
              'Percentage of batons that miss completely (lower is better)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlastHandicapChart(Map<GamePhase, List<BlastChartDataPoint>> data) {
    final allDates = _getAllDatesFromPhaseData(data);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Handicap Analysis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < allDates.length) {
                            return Text(
                              '${allDates[value.toInt()].month}/${allDates[value.toInt()].day}',
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: true),
                  lineBarsData: _buildBlastLineBarsData(data, (point) => point.handicap, allDates),
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Legend based on filter
            _buildBlastLegend(),
            const SizedBox(height: 8),
            
            Text(
              'Performance handicap based on efficiency (lower is better)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundProgressionAnalysisForSessions(List<PracticeSession> sessions) {
    final progression = _calculateRoundProgressionForSessions(sessions);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round Progression Analysis',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildProgressMetric(
                    'Early',
                    '${(progression.earlyRoundsAccuracy * 100).toStringAsFixed(1)}%',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildProgressMetric(
                    'Late',
                    '${(progression.lateRoundsAccuracy * 100).toStringAsFixed(1)}%',
                    Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionLengthAnalysisForSessions(List<PracticeSession> sessions) {
    final lengths = _calculateSessionLengthsForSessions(sessions);
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Lengths',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildLengthMetric('Avg', lengths.average.toStringAsFixed(1), Icons.timeline, Colors.blue),
                _buildLengthMetric('Min', '${lengths.shortest}', Icons.speed, Colors.green),
                _buildLengthMetric('Max', '${lengths.longest}', Icons.timer, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  RoundProgression _calculateRoundProgressionForSessions(List<PracticeSession> sessions) {
    if (sessions.isEmpty) {
      return RoundProgression(
        earlyRoundsAccuracy: 0.0,
        lateRoundsAccuracy: 0.0,
        dropOff: 0.0,
      );
    }
    
    int earlyThrows = 0;
    int earlyHits = 0;
    int lateThrows = 0;
    int lateHits = 0;
    
    for (final session in sessions) {
      for (int i = 0; i < session.completedRounds.length; i++) {
        final round = session.completedRounds[i];
        final roundNumber = i + 1;
        
        if (roundNumber <= 3) {
          earlyThrows += round.totalBatonThrows;
          earlyHits += round.hits;
        } else {
          lateThrows += round.totalBatonThrows;
          lateHits += round.hits;
        }
      }
    }
    
    final earlyAccuracy = earlyThrows > 0 ? earlyHits / earlyThrows : 0.0;
    final lateAccuracy = lateThrows > 0 ? lateHits / lateThrows : 0.0;
    final dropOff = earlyAccuracy - lateAccuracy;
    
    return RoundProgression(
      earlyRoundsAccuracy: earlyAccuracy,
      lateRoundsAccuracy: lateAccuracy,
      dropOff: dropOff,
    );
  }

  SessionLengths _calculateSessionLengthsForSessions(List<PracticeSession> sessions) {
    if (sessions.isEmpty) {
      return SessionLengths(average: 0, shortest: 0, longest: 0);
    }
    
    final lengths = sessions.map((s) => s.totalBatons).toList();
    
    return SessionLengths(
      average: lengths.reduce((a, b) => a + b) / lengths.length,
      shortest: lengths.reduce((a, b) => a < b ? a : b),
      longest: lengths.reduce((a, b) => a > b ? a : b),
    );
  }

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.9) return Colors.green;
    if (accuracy >= 0.7) return Colors.blue;
    if (accuracy >= 0.5) return Colors.orange;
    return Colors.red;
  }

  // ==================== LIFETIME AND RECENT CALCULATIONS ====================

  // Inkasting calculations
  double _calculateLifetimeOutOfBounds(List<InkastBlastSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    final totalOutOfBounds = sessions.fold(0, (sum, s) => sum + s.kubbsOutOfBounds);
    final totalInkastAttempts = sessions.fold(0, (sum, s) => sum + s.totalInkastKubbs + s.kubbsOutOfBounds);
    return totalInkastAttempts > 0 ? (totalOutOfBounds / totalInkastAttempts) * 100 : 0.0;
  }

  double _calculateRecentOutOfBounds(List<InkastBlastSession> sessions) {
    return _calculateLifetimeOutOfBounds(sessions);
  }

  double _calculateLifetimeFirstThrowSuccess(List<InkastBlastSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    
    int totalKubbsInBounds = 0;
    int totalClearedFirstThrow = 0;
    
    for (final session in sessions) {
      for (final round in session.rounds) {
        // Kubbs in bounds after inkasting (total inkast kubbs minus out of bounds)
        final kubbsInBounds = round.inkastKubbs - round.kubbsOutFirstAttempt - round.kubbsOutSecondAttempt;
        totalKubbsInBounds += kubbsInBounds;
        
        // Kubbs cleared with first baton throw
        if (round.batonThrows.isNotEmpty) {
          final firstThrow = round.batonThrows.first;
          if (firstThrow.isHit) {
            totalClearedFirstThrow += firstThrow.kubbsHit;
          }
        }
      }
    }
    
    return totalKubbsInBounds > 0 ? (totalClearedFirstThrow / totalKubbsInBounds) * 100 : 0.0;
  }

  double _calculateRecentFirstThrowSuccess(List<InkastBlastSession> sessions) {
    return _calculateLifetimeFirstThrowSuccess(sessions);
  }

  double _calculateLifetimeInkastsPerPenalty(List<InkastBlastSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    final totalInkasts = sessions.fold(0, (sum, s) => sum + s.totalInkastKubbs);
    final totalPenalties = sessions.fold(0, (sum, s) => sum + s.totalPenaltyKubbs);
    return totalPenalties > 0 ? totalInkasts / totalPenalties : totalInkasts.toDouble();
  }

  double _calculateRecentInkastsPerPenalty(List<InkastBlastSession> sessions) {
    return _calculateLifetimeInkastsPerPenalty(sessions);
  }

  double _calculateLifetimeInkastsPerNeighbor(List<InkastBlastSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    final totalInkasts = sessions.fold(0, (sum, s) => sum + s.totalInkastKubbs);
    final totalNeighbors = sessions.fold(0, (sum, s) => sum + s.totalNeighborKubbs);
    return totalNeighbors > 0 ? totalInkasts / totalNeighbors : totalInkasts.toDouble();
  }

  double _calculateRecentInkastsPerNeighbor(List<InkastBlastSession> sessions) {
    return _calculateLifetimeInkastsPerNeighbor(sessions);
  }

  // Blasting calculations
  double _calculateLifetimeBlastAccuracy(List<InkastBlastSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    final totalBatons = sessions.fold(0, (sum, s) => sum + s.totalBatonsUsed);
    final totalMisses = sessions.fold(0, (sum, s) => sum + s.totalMisses);
    final totalHits = totalBatons - totalMisses;
    return totalBatons > 0 ? (totalHits / totalBatons) * 100 : 0.0;
  }

  double _calculateRecentBlastAccuracy(List<InkastBlastSession> sessions) {
    return _calculateLifetimeBlastAccuracy(sessions);
  }

  double _calculateLifetimeKubbsPerBaton(List<InkastBlastSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    final totalKubbs = sessions.fold(0, (sum, s) => sum + s.totalKubbsKnockedDown);
    final totalBatons = sessions.fold(0, (sum, s) => sum + s.totalBatonsUsed);
    return totalBatons > 0 ? totalKubbs / totalBatons : 0.0;
  }

  double _calculateRecentKubbsPerBaton(List<InkastBlastSession> sessions) {
    return _calculateLifetimeKubbsPerBaton(sessions);
  }

  double _calculateLifetimeMissRate(List<InkastBlastSession> sessions) {
    if (sessions.isEmpty) return 0.0;
    final totalBatons = sessions.fold(0, (sum, s) => sum + s.totalBatonsUsed);
    final totalMisses = sessions.fold(0, (sum, s) => sum + s.totalMisses);
    return totalBatons > 0 ? (totalMisses / totalBatons) * 100 : 0.0;
  }

  double _calculateRecentMissRate(List<InkastBlastSession> sessions) {
    return _calculateLifetimeMissRate(sessions);
  }

  double _calculateLifetimeHandicap(List<InkastBlastSession> sessions) {
    return _calculateHandicap(sessions);
  }

  double _calculateRecentHandicap(List<InkastBlastSession> sessions) {
    return sessions.isNotEmpty ? _calculateHandicap(sessions) : 0.0;
  }
}

// Data classes
class ChartDataPoint {
  final DateTime date;
  final double accuracy;
  final int kubbs;
  final int batons;

  ChartDataPoint({
    required this.date,
    required this.accuracy,
    required this.kubbs,
    required this.batons,
  });
}

class OverallStats {
  final int totalSessions;
  final int totalBatons;
  final int totalKubbs;
  final double overallAccuracy;
  final int bestStreak;

  OverallStats({
    required this.totalSessions,
    required this.totalBatons,
    required this.totalKubbs,
    required this.overallAccuracy,
    required this.bestStreak,
  });
}

class TrainingStats {
  final int totalSessions;
  final int totalRounds;
  final int baselineClears;
  final int kingHits;
  final int kingAttempts;

  TrainingStats({
    required this.totalSessions,
    required this.totalRounds,
    required this.baselineClears,
    required this.kingHits,
    required this.kingAttempts,
  });
}

class SessionLengths {
  final double average;
  final int shortest;
  final int longest;

  SessionLengths({
    required this.average,
    required this.shortest,
    required this.longest,
  });
}

class PerformanceZones {
  final int excellent;
  final int good;
  final int average;
  final int needsWork;

  PerformanceZones({
    required this.excellent,
    required this.good,
    required this.average,
    required this.needsWork,
  });
}

class RecentFormStats {
  final double recentAvg;
  final double overallAvg;
  final int sessionCount;

  RecentFormStats({
    required this.recentAvg,
    required this.overallAvg,
    required this.sessionCount,
  });
}

class PersonalRecords {
  final double bestSessionAccuracy;
  final int longestStreak;
  final int perfectRounds;
  final int mostBaselineClears;
  final int bestAroundThePitchScore;

  PersonalRecords({
    required this.bestSessionAccuracy,
    required this.longestStreak,
    required this.perfectRounds,
    required this.mostBaselineClears,
    required this.bestAroundThePitchScore,
  });
}

class InkastBlastPersonalRecords {
  final int totalNeighbors;
  final int totalALines;
  final double overallHandicapEarly;
  final double overallHandicapMid;
  final double overallHandicapEnd;

  InkastBlastPersonalRecords({
    required this.totalNeighbors,
    required this.totalALines,
    required this.overallHandicapEarly,
    required this.overallHandicapMid,
    required this.overallHandicapEnd,
  });
}

class WeeklySummary {
  final int sessionsThisWeek;
  final int batonsThisWeek;
  final double accuracyThisWeek;
  final int baselineClearsThisWeek;

  WeeklySummary({
    required this.sessionsThisWeek,
    required this.batonsThisWeek,
    required this.accuracyThisWeek,
    required this.baselineClearsThisWeek,
  });
}

class AdvancedTrainingStats {
  final double firstThrowAccuracy;
  final double consistencyScore;
  final double clutchAccuracy;
  final double avgKubbsPerRound;

  AdvancedTrainingStats({
    required this.firstThrowAccuracy,
    required this.consistencyScore,
    required this.clutchAccuracy,
    required this.avgKubbsPerRound,
  });
}

class RoundProgression {
  final double earlyRoundsAccuracy;
  final double lateRoundsAccuracy;
  final double dropOff;

  RoundProgression({
    required this.earlyRoundsAccuracy,
    required this.lateRoundsAccuracy,
    required this.dropOff,
  });
}

// ==================== INKAST & BLAST STATISTICS CLASSES ====================

class InkastBlastStatistics {
  final double lifetimeHandicap;
  final double recentHandicap;
  final int totalSessions;
  final int totalRounds;
  final PhaseStatistics earlyPhaseStats;
  final PhaseStatistics midPhaseStats;
  final PhaseStatistics endPhaseStats;

  InkastBlastStatistics({
    required this.lifetimeHandicap,
    required this.recentHandicap,
    required this.totalSessions,
    required this.totalRounds,
    required this.earlyPhaseStats,
    required this.midPhaseStats,
    required this.endPhaseStats,
  });
}

class PhaseStatistics {
  final int roundsCompleted;
  final double firstCastSuccessRate;
  final double penaltyKubbRate;
  final double neighborRate;
  final double avgInitialBlast;
  final double kubbsPerBatonRatio;
  final double handicap;

  PhaseStatistics({
    required this.roundsCompleted,
    required this.firstCastSuccessRate,
    required this.penaltyKubbRate,
    required this.neighborRate,
    required this.avgInitialBlast,
    required this.kubbsPerBatonRatio,
    required this.handicap,
  });
}

// ==================== PROGRESS CHART DATA CLASSES ====================

class InkastChartDataPoint {
  final DateTime date;
  final double handicap;
  final double accuracy;
  final double efficiency;
  final double firstThrowSuccessRate;
  final double penaltyRate;
  final double outOfBoundsPercentage;
  final double inkastsPerPenaltyRatio;
  final double inkastsPerNeighborRatio;

  InkastChartDataPoint({
    required this.date,
    required this.handicap,
    required this.accuracy,
    required this.efficiency,
    required this.firstThrowSuccessRate,
    required this.penaltyRate,
    required this.outOfBoundsPercentage,
    required this.inkastsPerPenaltyRatio,
    required this.inkastsPerNeighborRatio,
  });
}

class BlastChartDataPoint {
  final DateTime date;
  final double accuracy;
  final double efficiency;
  final double missRate;
  final double averageKubbsPerBaton;
  final double handicap;

  BlastChartDataPoint({
    required this.date,
    required this.accuracy,
    required this.efficiency,
    required this.missRate,
    required this.averageKubbsPerBaton,
    required this.handicap,
  });
}

