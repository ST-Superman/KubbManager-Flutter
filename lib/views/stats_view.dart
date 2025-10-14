import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session_manager.dart';
import '../models/practice_session.dart';

/// Statistics view for tracking progress and performance over time
class StatsView extends StatefulWidget {
  const StatsView({super.key});

  @override
  State<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends State<StatsView> with TickerProviderStateMixin {
  late TabController _tabController;
  List<PracticeSession> _allSessions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    setState(() => _isLoading = false);
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
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: '8M Training', icon: Icon(Icons.sports)),
            Tab(text: 'Progress', icon: Icon(Icons.trending_up)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildTrainingTab(),
          _buildProgressTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    final stats = _calculateOverallStats();
    final recentForm = _calculateRecentForm();
    final personalRecords = _calculatePersonalRecords();
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
          
          // Recent Form Comparison
          _buildRecentFormCard(recentForm),
          const SizedBox(height: 16),
          
          // Key metrics cards
          _buildMetricsGrid(stats),
          const SizedBox(height: 24),
          
          // Personal Records
          _buildPersonalRecordsSection(personalRecords),
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
    final trainingStats = _calculateTrainingStats();
    final advancedStats = _calculateAdvancedTrainingStats();
    
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
          
          // Training-specific metrics
          _buildTrainingMetricsGrid(trainingStats),
          const SizedBox(height: 24),
          
          // Advanced Training Metrics
          _buildAdvancedMetricsGrid(advancedStats),
          const SizedBox(height: 24),
          
          // Round Progression Analysis
          _buildRoundProgressionAnalysis(),
          const SizedBox(height: 24),
          
          // Session length analysis
          _buildSessionLengthAnalysis(),
        ],
      ),
    );
  }

  Widget _buildProgressTab() {
    final chartData = _prepareChartData();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Progress Tracking',
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
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(OverallStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildMetricCard(
          'Total Sessions',
          '${stats.totalSessions}',
          Icons.calendar_today,
          Colors.blue,
          'Practice sessions completed',
        ),
        _buildMetricCard(
          'Total Batons',
          '${stats.totalBatons}',
          Icons.sports,
          Colors.green,
          'Batons thrown across all sessions',
        ),
        _buildMetricCard(
          'Overall Accuracy',
          '${(stats.overallAccuracy * 100).toStringAsFixed(1)}%',
          Icons.gps_fixed,
          Colors.orange,
          'Average hit rate across all sessions',
        ),
        _buildMetricCard(
          'Best Streak',
          '${stats.bestStreak}',
          Icons.local_fire_department,
          Colors.red,
          'Longest consecutive hit streak',
        ),
      ],
    );
  }

  Widget _buildTrainingMetricsGrid(TrainingStats stats) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      children: [
        _buildMetricCard(
          'Sessions',
          '${stats.totalSessions}',
          Icons.fitness_center,
          Colors.purple,
          '8M training sessions',
        ),
        _buildMetricCard(
          'Rounds',
          '${stats.totalRounds}',
          Icons.repeat,
          Colors.teal,
          'Total rounds completed',
        ),
        _buildMetricCard(
          'Baseline Clears',
          '${stats.baselineClears}',
          Icons.star,
          Colors.amber,
          'Rounds where all 5 baseline kubbs were knocked down. This doesn\'t require a perfect 6/6 - you just need to clear all 5 kubbs in the round.',
        ),
        _buildMetricCard(
          'King Hits',
          '${stats.kingHits}/${stats.kingAttempts}',
          Icons.emoji_events,
          Colors.deepOrange,
          'King shots occur when you clear all 5 baseline kubbs and still have a baton remaining. The 6th throw targets the king. This tracks your success rate on those king attempts.',
        ),
      ],
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
                        'Recent Form',
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

  Widget _buildPersonalRecordsSection(PersonalRecords records) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Personal Records',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildRecordRow(
              'Best Session',
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
              'Perfect Rounds',
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
          ],
        ),
      ),
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

  Widget _buildAdvancedMetricsGrid(AdvancedTrainingStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Advanced Metrics',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildMetricCard(
              'First Throw',
              '${(stats.firstThrowAccuracy * 100).toStringAsFixed(1)}%',
              Icons.looks_one,
              Colors.indigo,
              'Your accuracy on the first baton throw of each round. A lower percentage indicates "cold start" issues.',
            ),
            _buildMetricCard(
              'Consistency',
              '${(stats.consistencyScore * 100).toStringAsFixed(1)}%',
              Icons.show_chart,
              Colors.teal,
              'Standard deviation of your session accuracies. Higher score means more consistent performance (less variation).',
            ),
            _buildMetricCard(
              'Clutch Performance',
              '${(stats.clutchAccuracy * 100).toStringAsFixed(1)}%',
              Icons.stars,
              Colors.deepPurple,
              'Your accuracy when 3-4 kubbs are already down. Shows your performance under pressure.',
            ),
            _buildMetricCard(
              'Avg Kubbs/Round',
              stats.avgKubbsPerRound.toStringAsFixed(1),
              Icons.bar_chart,
              Colors.cyan,
              'Average number of baseline kubbs knocked down per round. Higher is better - maximum is 5.0.',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoundProgressionAnalysis() {
    final progression = _calculateRoundProgression();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Round Progression Analysis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Early rounds (1-3) vs Late rounds (4+)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.flash_on, color: Colors.green, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Early Rounds',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(progression.earlyRoundsAccuracy * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.battery_alert, color: Colors.orange, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          'Late Rounds',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(progression.lateRoundsAccuracy * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (progression.dropOff > 0.05) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You show a ${(progression.dropOff * 100).toStringAsFixed(1)}% drop-off in late rounds. Consider shorter sessions or rest breaks.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Great stamina! You maintain consistent performance throughout sessions.',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
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

  Widget _buildSessionLengthAnalysis() {
    final lengths = _calculateSessionLengths();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Session Length Analysis',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildLengthMetric(
                    'Average',
                    lengths.average.toStringAsFixed(1),
                    Icons.timeline,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildLengthMetric(
                    'Shortest',
                    '${lengths.shortest}',
                    Icons.speed,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildLengthMetric(
                    'Longest',
                    '${lengths.longest}',
                    Icons.timer,
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

  TrainingStats _calculateTrainingStats() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    return TrainingStats(
      totalSessions: completedSessions.length,
      totalRounds: completedSessions.fold(0, (sum, s) => sum + s.completedRounds.length),
      baselineClears: completedSessions.fold(0, (sum, s) => sum + s.totalBaselineClears),
      kingHits: completedSessions.fold(0, (sum, s) => sum + s.totalKingHits),
      kingAttempts: completedSessions.fold(0, (sum, s) => sum + s.totalKingThrowAttempts),
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

  SessionLengths _calculateSessionLengths() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    if (completedSessions.isEmpty) {
      return SessionLengths(average: 0, shortest: 0, longest: 0);
    }
    
    final lengths = completedSessions.map((s) => s.totalBatons).toList();
    
    return SessionLengths(
      average: lengths.reduce((a, b) => a + b) / lengths.length,
      shortest: lengths.reduce((a, b) => a < b ? a : b),
      longest: lengths.reduce((a, b) => a > b ? a : b),
    );
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

  PersonalRecords _calculatePersonalRecords() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    if (completedSessions.isEmpty) {
      return PersonalRecords(
        bestSessionAccuracy: 0.0,
        longestStreak: 0,
        perfectRounds: 0,
        mostBaselineClears: 0,
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
    
    return PersonalRecords(
      bestSessionAccuracy: bestSessionAccuracy,
      longestStreak: longestStreak,
      perfectRounds: perfectRounds,
      mostBaselineClears: mostBaselineClears,
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

  AdvancedTrainingStats _calculateAdvancedTrainingStats() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    if (completedSessions.isEmpty) {
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
    
    for (final session in completedSessions) {
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
    if (completedSessions.length > 1) {
      final accuracies = completedSessions.map((s) => s.accuracy).toList();
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

  RoundProgression _calculateRoundProgression() {
    final completedSessions = _allSessions.where((s) => s.isComplete).toList();
    
    if (completedSessions.isEmpty) {
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
    
    for (final session in completedSessions) {
      for (int i = 0; i < session.completedRounds.length; i++) {
        final round = session.completedRounds[i];
        final roundNumber = i + 1;
        
        if (roundNumber <= 3) {
          // Early rounds (1-3)
          earlyThrows += round.totalBatonThrows;
          earlyHits += round.hits;
        } else {
          // Late rounds (4+)
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

  Color _getAccuracyColor(double accuracy) {
    if (accuracy >= 0.9) return Colors.green;
    if (accuracy >= 0.7) return Colors.blue;
    if (accuracy >= 0.5) return Colors.orange;
    return Colors.red;
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

  PersonalRecords({
    required this.bestSessionAccuracy,
    required this.longestStreak,
    required this.perfectRounds,
    required this.mostBaselineClears,
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
