import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Badge counts shown on the activity-bar icons.
class NotificationBadges {
  final int review;
  final int graph;

  const NotificationBadges({
    this.review = 0,
    this.graph = 0,
  });

  int get total => review + graph;

  NotificationBadges copyWith({int? review, int? graph}) {
    return NotificationBadges(
      review: review ?? this.review,
      graph: graph ?? this.graph,
    );
  }
}

/// Tracks unread badge counts per activity-bar mode.
///
/// The badge for a mode = (live count now) − (count the user has already seen).
/// Visiting a mode advances its "seen" baseline, clearing the badge.
class NotificationNotifier extends StateNotifier<NotificationBadges> {
  NotificationNotifier() : super(const NotificationBadges()) {
    _loadSeen();
  }

  static const _seenKey = 'seen_notifications';

  Map<String, int> _seen = {'review': 0, 'graph': 0};
  Map<String, int> _live = {'review': 0, 'graph': 0};

  Future<void> _loadSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_seenKey);
      if (raw != null) {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        _seen = {
          for (final e in decoded.entries) e.key: (e.value as num).toInt(),
        };
      }
      _recompute();
    } catch (_) {}
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_seenKey, jsonEncode(_seen));
    } catch (_) {}
  }

  void _recompute() {
    state = NotificationBadges(
      review: (_live['review']! - (_seen['review'] ?? 0)).clamp(0, 1 << 30),
      graph: (_live['graph']! - (_seen['graph'] ?? 0)).clamp(0, 1 << 30),
    );
  }

  /// Update a category's live count (called when data loads/refreshes).
  void setLive(String mode, int count) {
    _live[mode] = count;
    _recompute();
  }

  /// Record that the user viewed a mode; its badge clears.
  Future<void> markSeen(String mode) async {
    _seen[mode] = _live[mode] ?? 0;
    await _persist();
    _recompute();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationNotifier, NotificationBadges>((ref) {
  return NotificationNotifier();
});