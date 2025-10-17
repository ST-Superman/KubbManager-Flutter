/// Models for Apple Watch session state and communication
/// Represents the minimal data needed to sync between phone and watch

/// Type of training session for watch display
enum WatchSessionType {
  eightMeter('8M Training'),
  inkastBlast('Inkast Blast'),
  aroundThePitch('Around Pitch'),
  fullGameSim('Full Game Sim');

  final String displayName;
  const WatchSessionType(this.displayName);
}

/// Current state of a training session for watch display
class WatchSessionState {
  final String sessionId;
  final WatchSessionType sessionType;
  final String title;
  final List<WatchContextItem> contextItems;
  final bool isActive;
  final DateTime lastUpdated;

  const WatchSessionState({
    required this.sessionId,
    required this.sessionType,
    required this.title,
    required this.contextItems,
    required this.isActive,
    required this.lastUpdated,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'sessionType': sessionType.name,
      'title': title,
      'contextItems': contextItems.map((item) => item.toJson()).toList(),
      'isActive': isActive,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory WatchSessionState.fromJson(Map<String, dynamic> json) {
    return WatchSessionState(
      sessionId: json['sessionId'] as String,
      sessionType: WatchSessionType.values.firstWhere(
        (e) => e.name == json['sessionType'],
      ),
      title: json['title'] as String,
      contextItems: (json['contextItems'] as List)
          .map((item) => WatchContextItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      isActive: json['isActive'] as bool,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
    );
  }

  WatchSessionState copyWith({
    String? sessionId,
    WatchSessionType? sessionType,
    String? title,
    List<WatchContextItem>? contextItems,
    bool? isActive,
    DateTime? lastUpdated,
  }) {
    return WatchSessionState(
      sessionId: sessionId ?? this.sessionId,
      sessionType: sessionType ?? this.sessionType,
      title: title ?? this.title,
      contextItems: contextItems ?? this.contextItems,
      isActive: isActive ?? this.isActive,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

/// A single piece of context information to display on the watch
class WatchContextItem {
  final String label;
  final String value;
  final WatchContextItemType type;

  const WatchContextItem({
    required this.label,
    required this.value,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'value': value,
      'type': type.name,
    };
  }

  factory WatchContextItem.fromJson(Map<String, dynamic> json) {
    return WatchContextItem(
      label: json['label'] as String,
      value: json['value'] as String,
      type: WatchContextItemType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
    );
  }
}

/// Type of context item (affects display on watch)
enum WatchContextItemType {
  primary,   // Main progress indicator (e.g., "Round 3")
  secondary, // Supporting info (e.g., "Throw 4/6")
  progress,  // Overall progress (e.g., "18/50")
}

/// Event sent from watch when user records a throw
class WatchThrowEvent {
  final String sessionId;
  final WatchThrowType throwType;
  final bool isHit;
  final int? kubbsHit; // For Inkast Blast
  final DateTime timestamp;

  const WatchThrowEvent({
    required this.sessionId,
    required this.throwType,
    required this.isHit,
    this.kubbsHit,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'throwType': throwType.name,
      'isHit': isHit,
      'kubbsHit': kubbsHit,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory WatchThrowEvent.fromJson(Map<String, dynamic> json) {
    return WatchThrowEvent(
      sessionId: json['sessionId'] as String,
      throwType: WatchThrowType.values.firstWhere(
        (e) => e.name == json['throwType'],
      ),
      isHit: json['isHit'] as bool,
      kubbsHit: json['kubbsHit'] as int?,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}

/// Type of throw being recorded
enum WatchThrowType {
  simple,      // Just hit/miss (8M, Around Pitch)
  multiKubb,   // Hit with kubb count (Inkast Blast)
  king,        // King throw
}

/// Configuration for watch input UI
class WatchInputConfig {
  final WatchThrowType throwType;
  final List<int>? kubbOptions; // For multi-kubb throws (e.g., [1, 2, 3])
  final bool showKingOption;

  const WatchInputConfig({
    required this.throwType,
    this.kubbOptions,
    this.showKingOption = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'throwType': throwType.name,
      'kubbOptions': kubbOptions,
      'showKingOption': showKingOption,
    };
  }

  factory WatchInputConfig.fromJson(Map<String, dynamic> json) {
    return WatchInputConfig(
      throwType: WatchThrowType.values.firstWhere(
        (e) => e.name == json['throwType'],
      ),
      kubbOptions: (json['kubbOptions'] as List<dynamic>?)?.cast<int>(),
      showKingOption: json['showKingOption'] as bool? ?? false,
    );
  }
}

/// Response from watch operations
class WatchResponse {
  final bool success;
  final String? error;

  const WatchResponse({
    required this.success,
    this.error,
  });

  factory WatchResponse.fromJson(Map<String, dynamic> json) {
    return WatchResponse(
      success: json['success'] as bool,
      error: json['error'] as String?,
    );
  }
}

