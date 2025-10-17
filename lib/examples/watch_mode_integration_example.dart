/// Example: How to integrate Apple Watch support into training views
/// 
/// This file demonstrates how to add "Watch Mode" functionality to any
/// training session. Copy the relevant parts into your actual training views.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/practice_session.dart';
import '../services/session_manager.dart';
import '../services/watch_connectivity_service.dart';
import '../services/watch_session_helper.dart';
import '../models/watch_session_state.dart';
import 'dart:async';

/// Example Training View with Watch Mode Integration
class ExampleTrainingViewWithWatch extends StatefulWidget {
  const ExampleTrainingViewWithWatch({super.key});

  @override
  State<ExampleTrainingViewWithWatch> createState() =>
      _ExampleTrainingViewWithWatchState();
}

class _ExampleTrainingViewWithWatchState
    extends State<ExampleTrainingViewWithWatch> with WidgetsBindingObserver {
  // Your existing state variables
  PracticeSession? _session;
  
  // NEW: Watch connectivity state
  final WatchConnectivityService _watchService = WatchConnectivityService();
  bool _isWatchModeEnabled = false;
  bool _isWatchConnected = false;
  StreamSubscription<WatchThrowEvent>? _throwEventSubscription;
  StreamSubscription<bool>? _connectionStateSubscription;
  StreamSubscription<String>? _errorSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // NEW: Initialize watch connectivity
    _initializeWatchConnectivity();
    
    // Your existing initialization
    _checkForActiveSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // NEW: Clean up watch connectivity
    _cleanupWatchConnectivity();
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // NEW: Keep watch session alive when app goes to background
    if (state == AppLifecycleState.paused && _isWatchModeEnabled) {
      debugPrint('🔵 App paused with watch mode active');
      // Session continues via watch
    } else if (state == AppLifecycleState.resumed && _isWatchModeEnabled) {
      debugPrint('🔵 App resumed with watch mode active');
      // Sync any changes that happened while paused
      _syncSessionToWatch();
    }
  }

  // ============================================================================
  // NEW: Watch Connectivity Methods
  // ============================================================================

  Future<void> _initializeWatchConnectivity() async {
    // Initialize the service
    final initialized = await _watchService.initialize();
    
    if (!initialized) {
      debugPrint('⚠️ Watch connectivity not available');
      return;
    }

    // Listen for connection state changes
    _connectionStateSubscription = _watchService.connectionState.listen((isConnected) {
      setState(() {
        _isWatchConnected = isConnected;
      });
      
      if (!isConnected && _isWatchModeEnabled) {
        _showSnackBar('Apple Watch disconnected', isError: true);
      }
    });

    // Listen for throw events from watch
    _throwEventSubscription = _watchService.throwEvents.listen((event) {
      if (event.sessionId == _session?.id) {
        _handleWatchThrow(event);
      }
    });

    // Listen for errors
    _errorSubscription = _watchService.errors.listen((error) {
      _showSnackBar('Watch error: $error', isError: true);
    });

    // Check initial connection state
    final isConnected = await _watchService.checkConnectionState();
    setState(() {
      _isWatchConnected = isConnected;
    });
  }

  void _cleanupWatchConnectivity() {
    _throwEventSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _errorSubscription?.cancel();
    
    if (_isWatchModeEnabled) {
      _watchService.endWatchSession();
    }
    
    _watchService.dispose();
  }

  /// Enable watch mode for the current session
  Future<void> _enableWatchMode() async {
    if (_session == null) {
      _showSnackBar('No active session', isError: true);
      return;
    }

    if (!_isWatchConnected) {
      _showSnackBar('Apple Watch not connected', isError: true);
      return;
    }

    // Create watch session state from current session
    final watchState = WatchSessionHelper.fromPracticeSession(_session!);
    
    // Start watch session
    final success = await _watchService.startWatchSession(watchState);
    
    if (success) {
      setState(() {
        _isWatchModeEnabled = true;
      });
      
      _showSnackBar('Watch mode enabled! Use your Apple Watch to record throws.');
      
      // Send initial input config
      final inputConfig = WatchSessionHelper.getInputConfigForPracticeSession(_session!);
      await _watchService.updateInputConfig(inputConfig);
    } else {
      _showSnackBar('Failed to enable watch mode', isError: true);
    }
  }

  /// Disable watch mode
  Future<void> _disableWatchMode() async {
    final success = await _watchService.endWatchSession();
    
    if (success) {
      setState(() {
        _isWatchModeEnabled = false;
      });
      
      _showSnackBar('Watch mode disabled');
    }
  }

  /// Handle a throw recorded on the watch
  Future<void> _handleWatchThrow(WatchThrowEvent event) async {
    debugPrint('🔵 Received throw from watch: ${event.isHit ? "HIT" : "MISS"}');
    
    // Process the throw just like a phone tap would
    await _onThrow(event.isHit);
    
    // Send haptic feedback to watch
    await _watchService.sendHapticFeedback(event.isHit ? 'success' : 'failure');
    
    // Update watch with new session state
    await _syncSessionToWatch();
  }

  /// Sync current session state to watch
  Future<void> _syncSessionToWatch() async {
    if (!_isWatchModeEnabled || _session == null) return;

    // Create updated watch state
    final watchState = WatchSessionHelper.fromPracticeSession(_session!);
    
    // Send to watch
    await _watchService.updateWatchSession(watchState);
    
    // Update input config if needed (e.g., if next throw is a king throw)
    final inputConfig = WatchSessionHelper.getInputConfigForPracticeSession(_session!);
    await _watchService.updateInputConfig(inputConfig);
  }

  // ============================================================================
  // Your Existing Methods (with watch integration points)
  // ============================================================================

  Future<void> _checkForActiveSession() async {
    // Your existing code...
    final sessionManager = context.read<SessionManager>();
    final activeSession = sessionManager.activePracticeSession;
    
    if (activeSession != null) {
      setState(() {
        _session = activeSession;
      });
    }
  }

  Future<void> _onThrow(bool isHit) async {
    if (_session == null) return;

    // Your existing throw handling code
    _session!.addBatonResult(isHit);
    
    final sessionManager = context.read<SessionManager>();
    await sessionManager.updatePracticeSession(_session!);

    setState(() {});

    // NEW: If watch mode enabled, sync the update
    if (_isWatchModeEnabled) {
      await _syncSessionToWatch();
    }

    // Check for session/round completion
    if (_session!.isTargetReached) {
      // NEW: Disable watch mode when session completes
      if (_isWatchModeEnabled) {
        await _disableWatchMode();
      }
      _showSessionCompleteDialog();
    }
  }

  void _showSessionCompleteDialog() {
    // Your existing dialog code
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Session Complete!'),
        content: Text('Total throws: ${_session!.totalBatons}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================================
  // UI Build Method
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('8M Training'),
        actions: [
          // NEW: Watch mode toggle button
          if (_session != null) _buildWatchModeButton(),
        ],
      ),
      body: _session == null ? _buildStartView() : _buildSessionView(),
    );
  }

  /// NEW: Watch mode button in app bar
  Widget _buildWatchModeButton() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: IconButton(
        icon: Icon(
          _isWatchModeEnabled
              ? Icons.watch
              : Icons.watch_outlined,
          color: _isWatchModeEnabled
              ? Colors.green
              : (_isWatchConnected ? Colors.white : Colors.grey),
        ),
        tooltip: _isWatchModeEnabled
            ? 'Disable Watch Mode'
            : (_isWatchConnected ? 'Enable Watch Mode' : 'Apple Watch Not Connected'),
        onPressed: _isWatchConnected
            ? (_isWatchModeEnabled ? _disableWatchMode : _enableWatchMode)
            : null,
      ),
    );
  }

  Widget _buildStartView() {
    return Center(
      child: ElevatedButton(
        onPressed: () {
          // Start session logic
        },
        child: const Text('Start Session'),
      ),
    );
  }

  Widget _buildSessionView() {
    return Column(
      children: [
        // NEW: Watch mode indicator banner
        if (_isWatchModeEnabled) _buildWatchModeBanner(),
        
        // Your existing session UI
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Throws: ${_session!.totalBatons}/${_session!.target}'),
                const SizedBox(height: 32),
                
                // Throw buttons (can be hidden/disabled in watch mode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: () => _onThrow(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        'HIT',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: () => _onThrow(false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                      child: const Text(
                        'MISS',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// NEW: Banner shown when watch mode is active
  Widget _buildWatchModeBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade500],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.watch, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          const Text(
            'Watch Mode Active',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: _isWatchConnected ? Colors.greenAccent : Colors.red,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Usage Notes
// ============================================================================

/// To integrate watch mode into your existing training views:
///
/// 1. Copy the watch-related instance variables to your State class
/// 2. Copy the _initializeWatchConnectivity() and related methods
/// 3. Call _initializeWatchConnectivity() in initState()
/// 4. Call _cleanupWatchConnectivity() in dispose()
/// 5. Add the watch mode button to your AppBar
/// 6. Call _syncSessionToWatch() after any state changes
/// 7. Handle _handleWatchThrow() events
/// 8. Optionally add the watch mode banner to your UI
///
/// For different session types (Inkast Blast, etc.):
/// - Use WatchSessionHelper.fromInkastBlastSession() instead
/// - Use appropriate input config getter
/// - Handle multi-kubb throws if needed (check event.kubbsHit)

