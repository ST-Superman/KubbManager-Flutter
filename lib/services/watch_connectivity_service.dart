import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/watch_session_state.dart';

/// Service to manage Apple Watch connectivity and communication
/// Handles bidirectional communication between Flutter and watchOS
class WatchConnectivityService {
  static const MethodChannel _channel = MethodChannel('com.kubb.watch/connectivity');
  
  // Stream controllers for watch events
  final _throwEventController = StreamController<WatchThrowEvent>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  
  bool _isInitialized = false;
  bool _isWatchConnected = false;
  WatchSessionState? _currentSessionState;

  // Public streams
  Stream<WatchThrowEvent> get throwEvents => _throwEventController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<String> get errors => _errorController.stream;
  
  bool get isWatchConnected => _isWatchConnected;
  bool get isInitialized => _isInitialized;
  WatchSessionState? get currentSessionState => _currentSessionState;

  /// Initialize the watch connectivity service
  /// Must be called before any other operations
  Future<bool> initialize() async {
    if (_isInitialized) {
      debugPrint('🔵 WatchConnectivity: Already initialized');
      return true;
    }

    // Only available on iOS
    if (!Platform.isIOS) {
      debugPrint('🔵 WatchConnectivity: Not available on ${Platform.operatingSystem}');
      return false;
    }

    try {
      debugPrint('🔵 WatchConnectivity: Initializing...');
      
      // Set up method call handler for watch -> Flutter communication
      _channel.setMethodCallHandler(_handleMethodCall);
      
      // Initialize native side
      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
      
      if (_isInitialized) {
        debugPrint('✅ WatchConnectivity: Initialized successfully');
        
        // Check initial connection state
        await checkConnectionState();
      } else {
        debugPrint('❌ WatchConnectivity: Initialization failed');
      }
      
      return _isInitialized;
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Initialization error: $e');
      _errorController.add('Failed to initialize watch connectivity: $e');
      return false;
    }
  }

  /// Handle method calls from native iOS code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    debugPrint('🔵 WatchConnectivity: Received method call: ${call.method}');
    
    try {
      switch (call.method) {
        case 'onThrowRecorded':
          _handleThrowRecorded(call.arguments);
          return {'success': true};
          
        case 'onConnectionStateChanged':
          _handleConnectionStateChanged(call.arguments);
          return {'success': true};
          
        case 'onError':
          _handleError(call.arguments);
          return {'success': true};
          
        default:
          debugPrint('⚠️ WatchConnectivity: Unknown method: ${call.method}');
          return {'success': false, 'error': 'Unknown method'};
      }
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error handling method call: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Handle throw recorded event from watch
  void _handleThrowRecorded(dynamic arguments) {
    try {
      final data = Map<String, dynamic>.from(arguments as Map);
      final event = WatchThrowEvent.fromJson(data);
      
      debugPrint('✅ WatchConnectivity: Throw recorded - Hit: ${event.isHit}');
      _throwEventController.add(event);
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error parsing throw event: $e');
      _errorController.add('Failed to parse throw event: $e');
    }
  }

  /// Handle connection state change from watch
  void _handleConnectionStateChanged(dynamic arguments) {
    try {
      final isConnected = arguments as bool;
      _isWatchConnected = isConnected;
      
      debugPrint('🔵 WatchConnectivity: Connection state changed: $isConnected');
      _connectionStateController.add(isConnected);
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error parsing connection state: $e');
    }
  }

  /// Handle error from watch
  void _handleError(dynamic arguments) {
    try {
      final error = arguments as String;
      debugPrint('❌ WatchConnectivity: Watch error: $error');
      _errorController.add(error);
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error parsing error message: $e');
    }
  }

  /// Check current watch connection state
  Future<bool> checkConnectionState() async {
    if (!_isInitialized) {
      debugPrint('⚠️ WatchConnectivity: Not initialized');
      return false;
    }

    try {
      final isConnected = await _channel.invokeMethod<bool>('isWatchConnected');
      _isWatchConnected = isConnected ?? false;
      
      debugPrint('🔵 WatchConnectivity: Watch connected: $_isWatchConnected');
      return _isWatchConnected;
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error checking connection: $e');
      return false;
    }
  }

  /// Start a watch session with the given state
  /// This sends the initial session data to the watch
  Future<bool> startWatchSession(WatchSessionState sessionState) async {
    if (!_isInitialized) {
      debugPrint('⚠️ WatchConnectivity: Not initialized');
      return false;
    }

    if (!_isWatchConnected) {
      debugPrint('⚠️ WatchConnectivity: Watch not connected');
      _errorController.add('Apple Watch is not connected');
      return false;
    }

    try {
      debugPrint('🔵 WatchConnectivity: Starting watch session: ${sessionState.sessionId}');
      
      final result = await _channel.invokeMethod<bool>(
        'startWatchSession',
        sessionState.toJson(),
      );
      
      if (result == true) {
        _currentSessionState = sessionState;
        debugPrint('✅ WatchConnectivity: Watch session started');
        return true;
      } else {
        debugPrint('❌ WatchConnectivity: Failed to start watch session');
        return false;
      }
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error starting watch session: $e');
      _errorController.add('Failed to start watch session: $e');
      return false;
    }
  }

  /// Update the current watch session state
  /// Use this to keep the watch in sync as the session progresses
  Future<bool> updateWatchSession(WatchSessionState sessionState) async {
    if (!_isInitialized || _currentSessionState == null) {
      debugPrint('⚠️ WatchConnectivity: No active watch session');
      return false;
    }

    try {
      debugPrint('🔵 WatchConnectivity: Updating watch session');
      
      final result = await _channel.invokeMethod<bool>(
        'updateWatchSession',
        sessionState.toJson(),
      );
      
      if (result == true) {
        _currentSessionState = sessionState;
        return true;
      } else {
        debugPrint('❌ WatchConnectivity: Failed to update watch session');
        return false;
      }
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error updating watch session: $e');
      return false;
    }
  }

  /// Update the input configuration for the watch
  /// Use this when the type of input needed changes (e.g., switching from kubb to king throw)
  Future<bool> updateInputConfig(WatchInputConfig config) async {
    if (!_isInitialized || _currentSessionState == null) {
      debugPrint('⚠️ WatchConnectivity: No active watch session');
      return false;
    }

    try {
      debugPrint('🔵 WatchConnectivity: Updating input config');
      
      final result = await _channel.invokeMethod<bool>(
        'updateInputConfig',
        config.toJson(),
      );
      
      return result ?? false;
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error updating input config: $e');
      return false;
    }
  }

  /// End the current watch session
  Future<bool> endWatchSession() async {
    if (!_isInitialized || _currentSessionState == null) {
      debugPrint('⚠️ WatchConnectivity: No active watch session');
      return false;
    }

    try {
      debugPrint('🔵 WatchConnectivity: Ending watch session');
      
      final result = await _channel.invokeMethod<bool>('endWatchSession');
      
      if (result == true) {
        _currentSessionState = null;
        debugPrint('✅ WatchConnectivity: Watch session ended');
        return true;
      } else {
        debugPrint('❌ WatchConnectivity: Failed to end watch session');
        return false;
      }
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error ending watch session: $e');
      return false;
    }
  }

  /// Send a haptic feedback to the watch
  Future<void> sendHapticFeedback(String type) async {
    if (!_isInitialized || !_isWatchConnected) return;

    try {
      await _channel.invokeMethod('sendHapticFeedback', {'type': type});
    } catch (e) {
      debugPrint('❌ WatchConnectivity: Error sending haptic: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    debugPrint('🔵 WatchConnectivity: Disposing...');
    _throwEventController.close();
    _connectionStateController.close();
    _errorController.close();
  }
}

