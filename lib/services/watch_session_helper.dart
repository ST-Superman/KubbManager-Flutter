import '../models/practice_session.dart';
import '../models/inkast_blast_session.dart';
import '../models/full_game_sim_session.dart';
import '../models/watch_session_state.dart';

/// Helper class to convert app session states to watch session states
/// Handles the logic for determining what context to show on the watch
class WatchSessionHelper {
  /// Create watch session state from a practice session (8M Training or Around the Pitch)
  static WatchSessionState fromPracticeSession(PracticeSession session) {
    final contextItems = <WatchContextItem>[];
    
    if (session.sessionType == SessionType.standard) {
      // 8-Meter Training
      final currentRound = session.currentRound;
      if (currentRound != null) {
        // Primary: Current round number
        contextItems.add(WatchContextItem(
          label: 'Round',
          value: '${currentRound.roundNumber}',
          type: WatchContextItemType.primary,
        ));
        
        // Secondary: Current throw in round
        contextItems.add(WatchContextItem(
          label: 'Throw',
          value: '${currentRound.totalBatonThrows + 1}/6',
          type: WatchContextItemType.secondary,
        ));
      }
      
      // Progress: Overall baton count
      contextItems.add(WatchContextItem(
        label: 'Total',
        value: '${session.totalBatons}/${session.target}',
        type: WatchContextItemType.progress,
      ));
      
      return WatchSessionState(
        sessionId: session.id,
        sessionType: WatchSessionType.eightMeter,
        title: '8M Training',
        contextItems: contextItems,
        isActive: true,
        lastUpdated: DateTime.now(),
      );
    } else {
      // Around the Pitch
      contextItems.add(WatchContextItem(
        label: 'Score',
        value: '${session.totalKubbs}/${session.targetScore}',
        type: WatchContextItemType.primary,
      ));
      
      // Determine current baseline (alternates 1 and 2)
      final currentBaseline = (session.totalBatons % 2) + 1;
      contextItems.add(WatchContextItem(
        label: 'Baseline',
        value: '$currentBaseline',
        type: WatchContextItemType.secondary,
      ));
      
      contextItems.add(WatchContextItem(
        label: 'Throws',
        value: '${session.totalBatons}',
        type: WatchContextItemType.progress,
      ));
      
      return WatchSessionState(
        sessionId: session.id,
        sessionType: WatchSessionType.aroundThePitch,
        title: 'Around Pitch',
        contextItems: contextItems,
        isActive: true,
        lastUpdated: DateTime.now(),
      );
    }
  }

  /// Create watch session state from an Inkast Blast session
  static WatchSessionState fromInkastBlastSession(
    InkastBlastSession session,
    InkastBlastRound? currentRound,
  ) {
    final contextItems = <WatchContextItem>[];
    
    if (currentRound != null) {
      // Primary: Round number
      contextItems.add(WatchContextItem(
        label: 'Round',
        value: '${currentRound.roundNumber}',
        type: WatchContextItemType.primary,
      ));
      
      // Secondary: Kubbs to clear
      final remaining = currentRound.kubbsRemaining;
      contextItems.add(WatchContextItem(
        label: 'Kubbs Left',
        value: '$remaining',
        type: WatchContextItemType.secondary,
      ));
      
      // Show in-bounds kubbs
      contextItems.add(WatchContextItem(
        label: 'In Bounds',
        value: '${currentRound.totalKubbsInBounds}',
        type: WatchContextItemType.secondary,
      ));
    }
    
    // Progress: Total rounds completed
    contextItems.add(WatchContextItem(
      label: 'Rounds',
      value: '${session.totalRounds}',
      type: WatchContextItemType.progress,
    ));
    
    return WatchSessionState(
      sessionId: session.id,
      sessionType: WatchSessionType.inkastBlast,
      title: 'Inkast Blast',
      contextItems: contextItems,
      isActive: true,
      lastUpdated: DateTime.now(),
    );
  }

  /// Create watch session state from a Full Game Simulation session
  static WatchSessionState fromFullGameSimSession(FullGameSimSession session) {
    final contextItems = <WatchContextItem>[];
    
    // Primary: Current round
    contextItems.add(WatchContextItem(
      label: 'Round',
      value: '${session.currentRound}',
      type: WatchContextItemType.primary,
    ));
    
    // Secondary: Current phase
    contextItems.add(WatchContextItem(
      label: 'Phase',
      value: session.currentPhase.displayName,
      type: WatchContextItemType.secondary,
    ));
    
    // Show attacking team
    contextItems.add(WatchContextItem(
      label: 'Team',
      value: '${session.currentAttackingTeam}',
      type: WatchContextItemType.secondary,
    ));
    
    // Progress: Total rounds
    contextItems.add(WatchContextItem(
      label: 'Total Rounds',
      value: '${session.totalRounds}',
      type: WatchContextItemType.progress,
    ));
    
    return WatchSessionState(
      sessionId: session.id,
      sessionType: WatchSessionType.fullGameSim,
      title: 'Full Game Sim',
      contextItems: contextItems,
      isActive: true,
      lastUpdated: DateTime.now(),
    );
  }

  /// Get the appropriate input configuration for the current session state
  static WatchInputConfig getInputConfigForPracticeSession(PracticeSession session) {
    final currentRound = session.currentRound;
    
    if (currentRound == null) {
      return const WatchInputConfig(throwType: WatchThrowType.simple);
    }
    
    // Check if next throw is a king throw (5 hits, 5 batons thrown)
    if (currentRound.hits >= 5 && currentRound.totalBatonThrows == 5) {
      return const WatchInputConfig(
        throwType: WatchThrowType.king,
        showKingOption: true,
      );
    }
    
    return const WatchInputConfig(throwType: WatchThrowType.simple);
  }

  /// Get input configuration for Inkast Blast (with kubb count options)
  static WatchInputConfig getInputConfigForInkastBlast(InkastBlastRound? round) {
    if (round == null) {
      return const WatchInputConfig(throwType: WatchThrowType.simple);
    }
    
    final remaining = round.kubbsRemaining;
    
    // Offer kubb count options based on remaining kubbs
    final options = <int>[];
    for (int i = 1; i <= remaining && i <= 4; i++) {
      options.add(i);
    }
    
    return WatchInputConfig(
      throwType: WatchThrowType.multiKubb,
      kubbOptions: options.isEmpty ? [1] : options,
    );
  }

  /// Get input configuration for Full Game Simulation
  static WatchInputConfig getInputConfigForFullGameSim(FullGameSimSession session) {
    // This would vary based on the current phase
    // For now, keep it simple
    return const WatchInputConfig(throwType: WatchThrowType.simple);
  }
}

