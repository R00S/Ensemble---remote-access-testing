import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'debug_logger.dart';

/// Represents a queued action that will be executed when connection is restored
class QueuedAction {
  final String type;
  final Map<String, dynamic> params;
  final DateTime queuedAt;

  QueuedAction({
    required this.type,
    required this.params,
    required this.queuedAt,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'params': params,
    'queuedAt': queuedAt.toIso8601String(),
  };

  factory QueuedAction.fromJson(Map<String, dynamic> json) => QueuedAction(
    type: json['type'] as String,
    params: json['params'] as Map<String, dynamic>,
    queuedAt: DateTime.parse(json['queuedAt'] as String),
  );
}

/// Service for queuing actions when offline and executing them when back online
class OfflineActionQueue {
  static OfflineActionQueue? _instance;
  static OfflineActionQueue get instance => _instance ??= OfflineActionQueue._();

  OfflineActionQueue._();

  final _logger = DebugLogger();
  static const _prefsKey = 'offline_action_queue';

  List<QueuedAction> _queue = [];
  bool _isProcessing = false;

  /// Get the current queue (for display)
  List<QueuedAction> get queue => List.unmodifiable(_queue);

  /// Check if there are pending actions
  bool get hasPendingActions => _queue.isNotEmpty;

  /// Number of pending actions
  int get pendingCount => _queue.length;

  /// Initialize and load persisted queue
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_prefsKey);
      if (queueJson != null) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue = decoded.map((j) => QueuedAction.fromJson(j as Map<String, dynamic>)).toList();
        _logger.log('📋 Loaded ${_queue.length} offline actions from storage');
      }
    } catch (e) {
      _logger.log('⚠️ Error loading offline action queue: $e');
    }
  }

  /// Queue an action for later execution
  Future<void> queueAction(String type, Map<String, dynamic> params) async {
    final action = QueuedAction(
      type: type,
      params: params,
      queuedAt: DateTime.now(),
    );
    _queue.add(action);
    await _persistQueue();
    _logger.log('📋 Queued offline action: $type');
  }

  /// Process all queued actions (call when connection is restored)
  Future<void> processQueue(Future<bool> Function(QueuedAction action) executor) async {
    if (_isProcessing || _queue.isEmpty) return;

    _isProcessing = true;
    _logger.log('🔄 Processing ${_queue.length} offline actions...');

    final processed = <QueuedAction>[];

    for (final action in _queue) {
      try {
        final success = await executor(action);
        if (success) {
          processed.add(action);
          _logger.log('✅ Processed offline action: ${action.type}');
        } else {
          _logger.log('⚠️ Failed to process offline action: ${action.type}');
        }
      } catch (e) {
        _logger.log('❌ Error processing offline action: $e');
      }
    }

    // Remove processed actions
    _queue.removeWhere((a) => processed.contains(a));
    await _persistQueue();

    _isProcessing = false;
    _logger.log('📋 ${processed.length} actions processed, ${_queue.length} remaining');
  }

  /// Clear all queued actions
  Future<void> clearQueue() async {
    _queue.clear();
    await _persistQueue();
    _logger.log('🗑️ Offline action queue cleared');
  }

  /// Persist queue to storage
  Future<void> _persistQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_queue.isEmpty) {
        await prefs.remove(_prefsKey);
      } else {
        final queueJson = jsonEncode(_queue.map((a) => a.toJson()).toList());
        await prefs.setString(_prefsKey, queueJson);
      }
    } catch (e) {
      _logger.log('⚠️ Error persisting offline action queue: $e');
    }
  }
}

/// Action types for offline queuing
class OfflineActionTypes {
  static const String toggleFavorite = 'toggle_favorite';
  static const String addToPlaylist = 'add_to_playlist';
  static const String removeFromPlaylist = 'remove_from_playlist';
}
