import 'package:flutter/material.dart';
import 'eight_meter_training_view.dart';
import 'eight_meter_training_enhanced.dart';

/// Landing page showing training mode options
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kubb Manager'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // App Header
            const _AppHeader(),
            const SizedBox(height: 32),

            // Training Mode Cards
            _TrainingModeCard(
              title: '8 Meter Practice',
              description:
                  'Practice throwing from 8 meters. Track your accuracy and build consistency.',
              icon: Icons.sports,
              color: Colors.blue,
              onTap: () {
                _showModeSelection(context);
              },
            ),
            const SizedBox(height: 16),

            _TrainingModeCard(
              title: 'Inkast Blast',
              description:
                  'Practice throwing inkast kubbs with varying difficulty levels.',
              icon: Icons.speed,
              color: Colors.orange,
              onTap: () {
                // TODO: Navigate to Inkast Blast
                _showComingSoon(context, 'Inkast Blast');
              },
            ),
            const SizedBox(height: 16),

            _TrainingModeCard(
              title: 'Full Game Sim',
              description:
                  'Simulate a full game with attacking, inkast, and field kubb phases.',
              icon: Icons.military_tech,
              color: Colors.green,
              onTap: () {
                // TODO: Navigate to Full Game Sim
                _showComingSoon(context, 'Full Game Sim');
              },
            ),
            const SizedBox(height: 32),

            // Stats Button
            OutlinedButton.icon(
              onPressed: () {
                _showComingSoon(context, 'Statistics');
              },
              icon: const Icon(Icons.bar_chart),
              label: const Text('View Statistics'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 16),

            // History Button
            OutlinedButton.icon(
              onPressed: () {
                _showComingSoon(context, 'Session History');
              },
              icon: const Icon(Icons.history),
              label: const Text('Session History'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature - Coming Soon!'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showModeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose Your Mode',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            
            // Standard Mode
            Card(
              child: ListTile(
                leading: const Icon(Icons.sports, color: Colors.blue, size: 40),
                title: const Text('Standard Mode',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Simple and straightforward'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const EightMeterTrainingView(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // Enhanced Mode
            Card(
              elevation: 4,
              color: Colors.blue.shade50,
              child: ListTile(
                leading: Stack(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: Colors.amber, size: 40),
                    Positioned(
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'NEW',
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
                title: const Text('Enhanced Mode',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text(
                    '🔥 Swipe gestures, animations, effects!'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const EightMeterTrainingEnhanced(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// App header with logo and description
class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo placeholder
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.sports_esports,
            size: 60,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // App Title
        Text(
          'Kubb Manager',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),

        // Description
        Text(
          'Track your practice sessions and improve your Kubb game',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Training mode card widget
class _TrainingModeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _TrainingModeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 32,
                  color: color,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),

              // Arrow
              Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

