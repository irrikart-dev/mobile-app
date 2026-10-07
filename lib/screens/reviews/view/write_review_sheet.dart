import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/network/api_envelope.dart';
import '../../../models/order_data.dart';
import '../../../models/review_data.dart';

/// Opens the write-review sheet for a specific paid order item.
/// [onSubmitted] refreshes the caller's review list — the sheet doesn't know
/// how the list is fetched, just that a review landed.
Future<void> showWriteReviewSheet(
  BuildContext context, {
  required String productId,
  required OrderItem orderItem,
  required VoidCallback onSubmitted,
}) async {
  final submitted = await showAppSheet<bool>(
    context,
    title: 'Write a review',
    builder: (_) => WriteReviewSheet(
      productId: productId,
      orderItem: orderItem,
      onSubmitted: onSubmitted,
    ),
  );
  if (submitted == true && context.mounted) {
    AppSnack.success(context, 'Thanks! Your review is live.');
  }
}

class WriteReviewSheet extends ConsumerStatefulWidget {
  const WriteReviewSheet({
    super.key,
    required this.productId,
    required this.orderItem,
    required this.onSubmitted,
  });

  final String productId;
  final OrderItem orderItem;
  final VoidCallback onSubmitted;

  @override
  ConsumerState<WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends ConsumerState<WriteReviewSheet> {
  static const _maxComment = 1000;
  static const _labels = ['Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  final _formKey = GlobalKey<FormState>();
  final _commentController = TextEditingController();
  int _rating = 0;
  bool _ratingMissing = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  String _errorMessage(Object e) {
    if (e is ApiException && e.isConflict) {
      return 'You have already reviewed this item.';
    }
    return friendlyError(e);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final formOk = _formKey.currentState?.validate() ?? false;
    if (_rating < 1) setState(() => _ratingMissing = true);
    if (!formOk || _rating < 1) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(reviewsRepositoryProvider).submit(
            orderItemId: widget.orderItem.id,
            rating: _rating,
            comment: _commentController.text,
          );
      widget.onSubmitted();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = _errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.orderItem.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySecondary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Column(
              children: [
                Text('How would you rate it?', style: context.text.title),
                const SizedBox(height: AppSpacing.smd),
                RatingInput(
                  value: _rating,
                  onChanged: (v) => setState(() {
                    _rating = v;
                    _ratingMissing = false;
                  }),
                ),
                const SizedBox(height: AppSpacing.sm),
                AnimatedSwitcher(
                  duration: AppDurations.fast,
                  child: Text(
                    _ratingMissing
                        ? 'Please choose a star rating'
                        : _rating == 0
                            ? 'Tap a star to rate'
                            : _labels[_rating - 1],
                    key: ValueKey('$_rating$_ratingMissing'),
                    style: context.text.label.copyWith(
                      color: _ratingMissing
                          ? c.error
                          : _rating == 0
                              ? c.textMuted
                              : c.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            label: 'Your review',
            optional: true,
            controller: _commentController,
            hint: 'How did it perform in your field? Installation, quality, '
                'value…',
            maxLines: 5,
            maxLength: _maxComment,
            textCapitalization: TextCapitalization.sentences,
            validator: (v) {
              final text = v?.trim() ?? '';
              if (text.isNotEmpty && text.length < 10) {
                return 'Add a little more detail (at least 10 characters)';
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xs),
          ListenableBuilder(
            listenable: _commentController,
            builder: (context, _) => Text(
              '${_commentController.text.length}/$_maxComment',
              textAlign: TextAlign.end,
              style: context.text.captionMuted,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.smd),
            InlineBanner(message: _error!, tone: Tone.error),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'Submit review',
            loading: _submitting,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
