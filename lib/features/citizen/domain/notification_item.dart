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
