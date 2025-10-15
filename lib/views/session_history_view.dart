import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session_manager.dart';
import '../services/database_service.dart';
import '../models/practice_session.dart';
import '../models/inkast_blast_session.dart';

/// View for displaying complete session history across all training modes
class SessionHistoryView extends StatefulWidget {
  const SessionHistoryView({super.key});

  @override
  State<SessionHistoryView> createState() => _SessionHistoryViewState();
}

class _SessionHistoryViewState extends State<SessionHistoryView> {
  List<SessionHistoryItem> _allSessions = [];
  bool _isLoading = true;
  String _filterType = 'all'; // all, 8meter, inkast, mixed

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);

    final sessionManager = context.read<SessionManager>();
    final practiceSessions = await sessionManager.getAllPracticeSessions();
    final inkastSessions = await sessionManager.getAllInkastBlastSessions();

    // Combine all sessions into a unified list
    final List<SessionHistoryItem> allSessions = [];

    // Add practice sessions (8 Meter)
    for (final session in practiceSessions) {
      allSessions.add(SessionHistoryItem.from8Meter(session));
    }

    // Add Inkast Blast sessions
    for (final session in inkastSessions) {
      allSessions.add(SessionHistoryItem.fromInkastBlast(session));
    }

    // Sort by date (most recent first)
    allSessions.sort((a, b) => b.date.compareTo(a.date));

    setState(() {
      _allSessions = allSessions;
      _isLoading = false;
    });
  }

  List<SessionHistoryItem> get _filteredSessions {
    if (_filterType == 'all') return _allSessions;
    return _allSessions.where((s) => s.type == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _filterType = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'all',
                child: Text('All Sessions'),
              ),
              const PopupMenuItem(
                value: '8meter',
                child: Text('8 Meter Training'),
              ),
              const PopupMenuItem(
                value: 'inkast',
                child: Text('Inkast & Blast'),
              ),
              const PopupMenuItem(
                value: 'mixed',
                child: Text('Mixed Phase'),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredSessions.isEmpty
              ? _buildEmptyState()
              : _buildSessionList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _filterType == 'all'
                  ? 'No sessions yet'
                  : 'No ${_getFilterLabel()} sessions',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start training to build your history!',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterLabel() {
    switch (_filterType) {
      case '8meter':
        return '8 Meter Training';
      case 'inkast':
        return 'Inkast & Blast';
      case 'mixed':
        return 'Mixed Phase';
      default:
        return 'All';
    }
  }

  Widget _buildSessionList() {
    return Column(
      children: [
        // Filter chips
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                '${_filteredSessions.length} ${_filteredSessions.length == 1 ? 'session' : 'sessions'}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              if (_filterType != 'all')
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _filterType = 'all';
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Filter'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredSessions.length,
            itemBuilder: (context, index) {
              final session = _filteredSessions[index];
              return _buildSessionCard(session);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(SessionHistoryItem session) {
    return Dismissible(
      key: Key(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text(
              'Delete',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _confirmDelete(session);
      },
      onDismissed: (direction) {
        _deleteSession(session);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        elevation: 2,
        child: InkWell(
          onTap: () => _showSessionDetails(session),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: session.color,
                  width: 4,
                ),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row
                  Row(
                    children: [
                      session.imagePath != null
                          ? Image.asset(
                              session.imagePath!,
                              width: 24,
                              height: 24,
                              color: session.color,
                              colorBlendMode: BlendMode.srcIn,
                            )
                          : Icon(
                              session.icon!,
                              color: session.color,
                              size: 24,
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              _formatDate(session.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red[300],
                        onPressed: () => _confirmAndDeleteSession(session),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Stats Row
                  _buildStatsForSession(session),

                  // Duration
                  if (session.duration != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.timer, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          _formatDuration(session.duration!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsForSession(SessionHistoryItem session) {
    switch (session.type) {
      case '8meter':
        return _build8MeterStats(session);
      case 'inkast':
        return _buildInkastBlastStats(session);
      case 'mixed':
        return _buildMixedPhaseStats(session);
      default:
        return const SizedBox();
    }
  }

  Widget _build8MeterStats(SessionHistoryItem session) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (session.stats['sessionSubtype'] != null)
          _buildStatChip(
            session.stats['sessionSubtype'],
            Icons.category,
            Colors.blue[700]!,
          ),
        if (session.stats['accuracy'] != null)
          _buildStatChip(
            '${session.stats['accuracy']}% Accuracy',
            Icons.gps_fixed,
            Colors.green,
          ),
        if (session.stats['totalBatons'] != null)
          _buildStatChip(
            '${session.stats['totalBatons']} Batons',
            Icons.sports,
            Colors.blue,
          ),
        if (session.stats['score'] != null && session.stats['target'] != null)
          _buildStatChip(
            '${session.stats['score']}/${session.stats['target']} Score',
            Icons.flag,
            Colors.orange,
          ),
      ],
    );
  }

  Widget _buildInkastBlastStats(SessionHistoryItem session) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (session.stats['gamePhase'] != null)
          _buildStatChip(
            session.stats['gamePhase'],
            Icons.filter_list,
            Colors.deepOrange[700]!,
          ),
        if (session.stats['handicap'] != null)
          _buildStatChip(
            'Handicap: ${session.stats['handicap']}',
            Icons.trending_up,
            double.parse(session.stats['handicap'].toString().replaceAll('+', '')) >= 0
                ? Colors.green
                : Colors.red,
          ),
        if (session.stats['rounds'] != null)
          _buildStatChip(
            '${session.stats['rounds']} Rounds',
            Icons.repeat,
            Colors.deepOrange,
          ),
        if (session.stats['efficiency'] != null)
          _buildStatChip(
            '${session.stats['efficiency']} K/B',
            Icons.analytics,
            Colors.purple,
          ),
      ],
    );
  }

  Widget _buildMixedPhaseStats(SessionHistoryItem session) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        if (session.stats['modeType'] != null)
          _buildStatChip(
            session.stats['modeType'],
            Icons.sports_esports,
            Colors.green[700]!,
          ),
      ],
    );
  }

  Widget _buildStatChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      final hours = date.hour;
      final minutes = date.minute;
      final period = hours >= 12 ? 'PM' : 'AM';
      final hour12 = hours > 12 ? hours - 12 : (hours == 0 ? 12 : hours);
      return 'Today at $hour12:${minutes.toString().padLeft(2, '0')} $period';
    }
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';

    return '${date.month}/${date.day}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  Future<bool> _confirmDelete(SessionHistoryItem session) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session?'),
        content: Text(
          'Delete "${session.title}" from ${_formatDate(session.date)}?\n\nThis cannot be undone.',
        ),
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

    return confirmed ?? false;
  }

  Future<void> _confirmAndDeleteSession(SessionHistoryItem session) async {
    final confirmed = await _confirmDelete(session);
    if (confirmed) {
      _deleteSession(session);
    }
  }

  Future<void> _deleteSession(SessionHistoryItem session) async {
    final db = DatabaseService.instance;

    try {
      if (session.type == '8meter') {
        await db.deletePracticeSession(session.id);
      } else if (session.type == 'inkast') {
        await db.deleteInkastBlastSession(session.id);
      }

      // Reload sessions
      await _loadSessions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Session deleted'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting session: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showSessionDetails(SessionHistoryItem session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    session.imagePath != null
                        ? Image.asset(
                            session.imagePath!,
                            width: 32,
                            height: 32,
                            color: session.color,
                            colorBlendMode: BlendMode.srcIn,
                          )
                        : Icon(session.icon!, color: session.color, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _formatDate(session.date),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),

                // Full stats
                Text(
                  'Session Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),

                // Display all stats
                ...session.stats.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatStatKey(entry.key),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          entry.value.toString(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 24),

                // Delete button
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _confirmAndDeleteSession(session);
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete Session'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatStatKey(String key) {
    // Convert camelCase to Title Case with spaces
    final result = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    );
    return result[0].toUpperCase() + result.substring(1);
  }
}

// ============================================================================
// Session History Item Model
// ============================================================================

class SessionHistoryItem {
  final String id;
  final String type; // '8meter', 'inkast', 'mixed'
  final String title;
  final DateTime date;
  final Duration? duration;
  final Color color;
  final IconData? icon;
  final String? imagePath;
  final Map<String, dynamic> stats;

  SessionHistoryItem({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.duration,
    required this.color,
    this.icon,
    this.imagePath,
    required this.stats,
  });

  factory SessionHistoryItem.from8Meter(PracticeSession session) {
    final duration = session.endTime?.difference(session.startTime);

    final accuracy = session.totalBatons > 0
        ? ((session.totalKubbs / session.totalBatons) * 100).toStringAsFixed(1)
        : '0.0';

    String subtitle = '';
    if (session.sessionType == SessionType.aroundThePitch) {
      subtitle = 'Around the Pitch';
    } else {
      subtitle = 'Standard Mode';
    }

    return SessionHistoryItem(
      id: session.id,
      type: '8meter',
      title: '8 Meter Training',
      date: session.date,
      duration: duration,
      color: Colors.blue,
      imagePath: 'assets/icons/8meter.png',
      stats: {
        'sessionSubtype': subtitle,
        'accuracy': accuracy,
        'totalBatons': session.totalBatons,
        'totalKubbs': session.totalKubbs,
        'totalRounds': session.completedRounds.length,
        if (session.sessionType == SessionType.aroundThePitch) ...{
          'score': session.totalBatons,
          'target': session.targetScore,
        },
      },
    );
  }

  factory SessionHistoryItem.fromInkastBlast(InkastBlastSession session) {
    final duration = session.endTime?.difference(session.startTime);

    final efficiency = session.totalBatonsUsed > 0
        ? (session.totalKubbsKnockedDown / session.totalBatonsUsed)
            .toStringAsFixed(2)
        : '0.00';

    // Calculate average handicap for this session
    double avgHandicap = 0.0;
    if (session.rounds.isNotEmpty) {
      final totalHandicap = session.rounds.fold(
        0,
        (sum, round) => sum + round.performanceVsTarget,
      );
      avgHandicap = totalHandicap / session.rounds.length;
    }

    return SessionHistoryItem(
      id: session.id,
      type: 'inkast',
      title: 'Inkast & Blast',
      date: session.date,
      duration: duration,
      color: Colors.deepOrange,
      imagePath: 'assets/icons/inkastblast.png',
      stats: {
        'gamePhase': session.gamePhase.displayName,
        'handicap': '${avgHandicap >= 0 ? '+' : ''}${avgHandicap.toStringAsFixed(2)}',
        'rounds': session.totalRounds,
        'efficiency': efficiency,
        'totalBatons': session.totalBatonsUsed,
        'totalKubbs': session.totalKubbsKnockedDown,
        'penaltyRate': '${(session.penaltyRate * 100).toStringAsFixed(1)}%',
      },
    );
  }
}

