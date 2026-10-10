/// Mirrors `public.notifications`. `isRead` is UI-only state -- the schema
/// does not have a read/unread column, only `delivery_status`.
class NotificationItem {
  const NotificationItem({
    required this.notificationId,
    required this.message,
    required this.channel,
    required this.deliveryStatus,
    required this.createdAt,
    this.isRead = false,
  });

  final String notificationId;
  final String message;
  final String channel;
  final String deliveryStatus;
  final DateTime createdAt;
  final bool isRead;

  /// User-facing name for [channel], e.g. `in_app` -> "App Notification".
  String get channelLabel {
    return switch (channel.toLowerCase().trim()) {
      'app' || 'in_app' || 'in-app' => 'App Notification',
      'sms' => 'SMS Message',
      'email' => 'Email',
      'push' => 'Push Notification',
      final other when other.isEmpty => 'Notification',
      final other => '${other[0].toUpperCase()}${other.substring(1).replaceAll('_', ' ')}',
    };
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      notificationId: notificationId,
      message: message,
      channel: channel,
      deliveryStatus: deliveryStatus,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
