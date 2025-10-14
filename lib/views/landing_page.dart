import 'package:flutter/material.dart';
import 'eight_meter_training_view.dart';
import 'around_the_pitch_training_view.dart';
import 'inkast_blast_training_view.dart';
import 'stats_view.dart';
import '../models/inkast_blast_session.dart';

/// Landing page showing training mode options
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kubb Trainer'),
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
              imagePath: 'assets/icons/8meter.png',
              color: Colors.blue.shade800,
              onTap: () {
                _showModeSelection(context);
              },
            ),
            const SizedBox(height: 16),

            _TrainingModeCard(
              title: 'Inkast Blast',
              description:
                  'Practice your inkasting, then clear your field kubbs (blast)',
              imagePath: 'assets/icons/inkastblast.png',
              color: Colors.deepOrange.shade700,
              onTap: () {
                _showInkastBlastModeSelection(context);
              },
            ),
            const SizedBox(height: 16),

            _TrainingModeCard(
              title: 'Mixed Phase Training',
              description:
                  'These sessions work on both 8 Meter and Inkast/Blast skills.',
              imagePath: 'assets/icons/kubbEquipment.png',
              color: Colors.green.shade700,
              onTap: () {
                _showMixedPhaseModeSelection(context);
              },
            ),
            const SizedBox(height: 32),

            // Stats Button
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const StatsView(),
                  ),
                );
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
                leading: Image.asset(
                  'assets/icons/8meter.png',
                  width: 40,
                  height: 40,
                  color: Colors.blue,
                  colorBlendMode: BlendMode.srcIn,
                ),
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
            const SizedBox(height: 12),
            
            // Around the Pitch Mode
            Card(
              child: ListTile(
                leading: Image.asset(
                  'assets/icons/aroundThePitch.png',
                  width: 40,
                  height: 40,
                  color: Colors.blue,
                  colorBlendMode: BlendMode.srcIn,
                ),
                title: const Text('Around the Pitch',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('All 10 baseline kubbs + king'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AroundThePitchTrainingView(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // More modes coming soon message
            const Text(
              'More modes coming soon!',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showInkastBlastModeSelection(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.75,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            controller: scrollController,
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
                
                // Early-Game Mode
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.looks_one, color: Colors.orange, size: 40),
                    title: const Text('Early-Game',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Inkast / blast practice with 1-3 kubbs'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const InkastBlastTrainingView(
                            gamePhase: GamePhase.early,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Mid-Game Mode
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.looks_two, color: Colors.orange, size: 40),
                    title: const Text('Mid-Game',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Inkast / blast practice with 4-7 kubbs'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const InkastBlastTrainingView(
                            gamePhase: GamePhase.mid,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // End-Game Mode
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.looks_3, color: Colors.orange, size: 40),
                    title: const Text('End-Game',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Inkast / blast practice with 8-10 kubbs'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const InkastBlastTrainingView(
                            gamePhase: GamePhase.end,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                
                // Random Mode
                Card(
                  child: ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          '?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: const Text('Random',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Inkast / blast practice with 1-10 kubbs'),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const InkastBlastTrainingView(
                            gamePhase: GamePhase.all,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMixedPhaseModeSelection(BuildContext context) {
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
            
            // Full Game Sim Mode
            Card(
              child: ListTile(
                leading: const Icon(Icons.sports_esports, color: Colors.green, size: 40),
                title: const Text('Full Game Sim',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Simulate a complete Kubb game'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.pop(context);
                  _showComingSoon(context, 'Full Game Sim');
                },
              ),
            ),
            const SizedBox(height: 16),
            
            // More modes coming soon message
            const Text(
              'More modes coming soon!',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
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
          child: Image.asset(
            'assets/icons/kubbTrainer.png',
            width: 60,
            height: 60,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 16),

        // App Title
        Text(
          'Kubb Trainer',
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
  final IconData? icon;  // Now optional
  final String? imagePath;  // New: path to custom image
  final Color color;
  final VoidCallback onTap;

  const _TrainingModeCard({
    required this.title,
    required this.description,
    this.icon,  // Optional
    this.imagePath,  // Optional
    required this.color,
    required this.onTap,
  }) : assert(icon != null || imagePath != null, 'Either icon or imagePath must be provided');

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
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: imagePath != null
                    ? Image.asset(
                        imagePath!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        color: color,
                        colorBlendMode: BlendMode.srcIn,
                      )
                    : Icon(
                        icon!,
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

