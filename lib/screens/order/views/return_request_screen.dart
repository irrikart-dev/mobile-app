import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../components/ui/ui.dart';
import '../../../models/order_data.dart';
import '../../../models/returns_data.dart';
import 'order_actions.dart';
import 'order_ui.dart';

const _maxPhotos = 5;

/// Units of [item] not already covered by a live (non-rejected) return.
int returnableQuantity(Order order, OrderItem item) {
  final taken = order.returns
      .where((r) => r.status != ReturnStatus.rejected)
      .expand((r) => r.items)
      .where((i) => i.orderItemId == item.id)
      .fold<int>(0, (sum, i) => sum + i.quantity);
  return (item.quantity - taken).clamp(0, item.quantity);
}

/// "Return items" (`POST /returns`): pick lines and quantities, return or
/// replace, a reason, optional details and up to 5 photos. Pops `true` once
/// the request is in.
class ReturnRequestScreen extends ConsumerStatefulWidget {
  const ReturnRequestScreen({super.key, required this.order});

  final Order order;

  @override
  ConsumerState<ReturnRequestScreen> createState() =>
      _ReturnRequestScreenState();
}

class _ReturnRequestScreenState extends ConsumerState<ReturnRequestScreen> {
  static const _other = 'Other';

  final _details = TextEditingController();
  final _otherReason = TextEditingController();
  late final Map<String, int> _qty = {
    for (final i in widget.order.items)
      i.id: returnableQuantity(widget.order, i),
  };
  final List<XFile> _photos = [];
  String _type = 'RETURN';
  String? _choice;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    _otherReason.dispose();
    super.dispose();
  }

  String get _reason =>
      _choice == _other ? _otherReason.text.trim() : (_choice ?? '');

  bool get _valid =>
      _reason.length >= 3 &&
      _reason.length <= 200 &&
      _qty.values.any((q) => q > 0);

  Future<void> _addPhotos(ImageSource source) async {
    final picker = ImagePicker();
    final room = _maxPhotos - _photos.length;
    try {
      // Compressed on-device so each stays well under the 5 MB limit.
      final picked = source == ImageSource.camera
          ? [
              if (await picker.pickImage(
                source: source,
                maxWidth: 1600,
                imageQuality: 80,
              )
                  case final f?)
                f,
            ]
          : await picker.pickMultiImage(
              maxWidth: 1600,
              imageQuality: 80,
              limit: room,
            );
      if (mounted) setState(() => _photos.addAll(picked.take(room)));
    } catch (_) {
      if (mounted) AppSnack.error(context, 'Could not open your photos.');
    }
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(returnsRepositoryProvider);
    try {
      final urls = <String>[];
      for (final p in _photos) {
        urls.add(await repo.uploadPhoto(p));
      }
      await repo.create(
        orderId: widget.order.id,
        type: _type,
        reason: _reason,
        details: _details.text,
        photoUrls: urls,
        items: {
          for (final e in _qty.entries)
            if (e.value > 0) e.key: e.value,
        },
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = orderErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final order = widget.order;
    final until = order.returnableUntil;

    return Scaffold(
      backgroundColor: c.background,
      appBar: const AppTopBar(title: 'Return items'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          AppSpacing.sm,
          AppSpacing.gutter,
          AppSpacing.xl + context.bottomInset,
        ),
        children: [
          if (until != null)
            Text(
              'You can request a return until '
              '${DateFormat('d MMM, h:mm a').format(until)}.',
              style: context.text.bodySecondary,
            ),
          const SizedBox(height: AppSpacing.lg),
          const OverlineHeader('What would you like?'),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              AppChip(
                label: 'Return',
                selected: _type == 'RETURN',
                onTap: _busy ? null : () => setState(() => _type = 'RETURN'),
              ),
              AppChip(
                label: 'Replacement',
                selected: _type == 'REPLACE',
                onTap: _busy ? null : () => setState(() => _type = 'REPLACE'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const OverlineHeader('Items'),
          for (final item in order.items)
            _ItemPicker(
              item: item,
              max: returnableQuantity(order, item),
              value: _qty[item.id] ?? 0,
              onChanged:
                  _busy ? null : (q) => setState(() => _qty[item.id] = q),
            ),
          const SizedBox(height: AppSpacing.lg),
          const OverlineHeader('Reason'),
          for (final reason in [...returnReasonPresets, _other])
            ReasonRow(
              label: reason,
              selected: _choice == reason,
              onTap: _busy ? null : () => setState(() => _choice = reason),
            ),
          if (_choice == _other) ...[
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Your reason',
              hint: 'At least 3 characters',
              controller: _otherReason,
              maxLength: 200,
              enabled: !_busy,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() {}),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Details',
            hint: 'What went wrong? Anything our team should know.',
            controller: _details,
            maxLines: 3,
            maxLength: 2000,
            optional: true,
            enabled: !_busy,
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpacing.lg),
          OverlineHeader(
            'Photos',
            trailing: Text(
              '${_photos.length}/$_maxPhotos',
              style: context.text.captionMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in _photos)
                _PhotoThumb(
                  file: p,
                  onRemove:
                      _busy ? null : () => setState(() => _photos.remove(p)),
                ),
              if (_photos.length < _maxPhotos && !_busy) ...[
                _AddPhotoTile(
                  icon: Icons.photo_camera_rounded,
                  label: 'Camera',
                  onTap: () => _addPhotos(ImageSource.camera),
                ),
                _AddPhotoTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => _addPhotos(ImageSource.gallery),
                ),
              ],
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            InlineBanner(message: _error!, tone: Tone.error),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label:
                _type == 'REPLACE' ? 'Request replacement' : 'Request return',
            loading: _busy,
            onPressed: _valid ? _submit : null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Our team reviews every request and arranges the pickup. '
            'Refunds for returns are settled by our team directly.',
            style: context.text.captionMuted,
          ),
        ],
      ),
    );
  }
}

class _ItemPicker extends StatelessWidget {
  const _ItemPicker({
    required this.item,
    required this.max,
    required this.value,
    required this.onChanged,
  });

  final OrderItem item;
  final int max;
  final int value;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd),
      child: Row(
        children: [
          ProductTile(image: item.image, size: 52),
          const SizedBox(width: AppSpacing.smd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: context.text.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  max == 0 ? 'Already returned' : 'Bought ${item.quantity}',
                  style: context.text.captionMuted,
                ),
              ],
            ),
          ),
          if (max > 0)
            QuantityStepper(
              value: value,
              min: 0,
              max: max,
              size: StepperSize.sm,
              busy: onChanged == null,
              onChanged: onChanged ?? (_) {},
            ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.file, required this.onRemove});

  final XFile file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: AppRadius.smAll,
          child: Image.file(
            File(file.path),
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        if (onRemove != null)
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              onTap: onRemove,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: context.colors.textPrimary,
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: context.colors.surface,
                  semanticLabel: 'Remove photo',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          borderRadius: AppRadius.smAll,
          border: Border.all(color: c.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: c.primary, size: AppIconSize.sm),
            const SizedBox(height: AppSpacing.xxs),
            Text(label, style: context.text.caption),
          ],
        ),
      ),
    );
  }
}
