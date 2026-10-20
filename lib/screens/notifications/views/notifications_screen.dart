import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../components/ui/ui.dart';
import '../../../core/push/push_service.dart';
import '../../../models/notification_data.dart';
import '../../../models/order_data.dart' show orderErrorMessage;
import '../../order/views/order_ui.dart';

/// The notification centre (`GET /notifications`). Opening it marks
/// everything read; unread rows keep their dot until the next visit.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _markedRead = false;

  /// Once per visit, after the list has loaded (so the dots render first).
  void _markAllRead() {
    if (_markedRead) return;
    _markedRead = true;
    ref
        .read(notificationsRepositoryProvider)
        .markAllRead()
        .then((_) => ref.invalidate(unreadNotificationsProvider))
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final page = ref.watch(notificationsProvider);
    ref.listen(notificationsProvider, (_, next) {
      if (next.valueOrNull?.unread case final n? when n > 0) _markAllRead();
    });

    return Scaffold(
      backgroundColor: c.background,
      appBar: const AppTopBar(title: 'Notifications'),
      body: page.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          error: err,
          message: orderErrorMessage(err),
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (page) => page.items.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_none_rounded,
                title: 'No notifications yet',
                message: 'Order and return updates will show up here.',
              )
            : RefreshIndicator(
                color: c.primary,
                onRefresh: () => ref.refresh(notificationsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.gutter,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: page.items.length,
                  separatorBuilder: (_, __) => const Hairline(),
                  itemBuilder: (context, i) =>
                      _NotificationRow(item: page.items[i]),
                ),
              ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.item});

  final AppNotification item;

  IconData get _icon => switch (item.type) {
        'ORDER_SHIPPED' => Icons.local_shipping_rounded,
        'ORDER_DELIVERED' => Icons.inventory_2_rounded,
        'ORDER_CANCELLED' => Icons.cancel_outlined,
        'ORDER_CONFIRMED' => Icons.check_circle_rounded,
        'CAMPAIGN' => Icons.campaign_rounded,
        _ when item.type.startsWith('RETURN_') =>
          Icons.assignment_return_rounded,
        _ => Icons.notifications_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: () => openNotificationTarget(context, item.data),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd + 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.tint, shape: BoxShape.circle),
              child: Icon(_icon, size: AppIconSize.sm, color: c.primary),
            ),
            const SizedBox(width: AppSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: context.text.title),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(item.body, style: context.text.bodySecondary),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    DateFormat('d MMM, h:mm a').format(item.createdAt),
                    style: context.text.captionMuted,
                  ),
                ],
              ),
            ),
            if (!item.read)
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpacing.sm,
                  top: AppSpacing.xs,
                ),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
