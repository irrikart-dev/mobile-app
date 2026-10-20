import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../components/ui/ui.dart';
import '../../../core/auth/auth_service.dart';
import '../../../core/network/api_envelope.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order_data.dart' show orderErrorMessage;
import '../../../models/rfq_data.dart';
import '../../../route/route_constants.dart';
import '../../order/views/order_ui.dart';

/// Opens the bulk-quote form (`POST /rfq`). With [productId] it asks about
/// that product; without, it's a free-text "bulk enquiry".
Future<void> showQuoteRequestSheet(
  BuildContext context, {
  String? productId,
  String? productName,
}) async {
  final ref = ProviderScope.containerOf(context, listen: false);
  if (!ref.read(isSignedInProvider)) {
    AppSnack.show(
      context,
      'Sign in to request a bulk quote.',
      actionLabel: 'Sign in',
      onAction: () => Navigator.of(context, rootNavigator: true)
          .pushNamedAndRemoveUntil(logInScreenRoute, (_) => false),
    );
    return;
  }
  final sent = await showAppSheet<QuoteRequest>(
    context,
    title: 'Request a bulk quote',
    builder: (_) =>
        _QuoteRequestForm(productId: productId, productName: productName),
  );
  if (sent == null || !context.mounted) return;
  ref.invalidate(myQuoteRequestsProvider);
  final phone = ref.read(authServiceProvider).currentUser?.phoneNumber;
  AppSnack.show(
    context,
    phone == null || phone.isEmpty
        ? 'Submitted. Our team will contact you soon.'
        : 'Submitted. Our team will contact you on $phone.',
    tone: Tone.success,
    actionLabel: 'View',
    onAction: () => Navigator.pushNamed(context, quoteRequestsScreenRoute),
    duration: const Duration(seconds: 4),
  );
}

class _QuoteRequestForm extends ConsumerStatefulWidget {
  const _QuoteRequestForm({this.productId, this.productName});

  final String? productId;
  final String? productName;

  @override
  ConsumerState<_QuoteRequestForm> createState() => _QuoteRequestFormState();
}

class _QuoteRequestFormState extends ConsumerState<_QuoteRequestForm> {
  final _quantity = TextEditingController();
  final _requirements = TextEditingController();
  final _targetPrice = TextEditingController();
  late String? _productId = widget.productId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _requirements.dispose();
    _targetPrice.dispose();
    super.dispose();
  }

  int? get _qty => int.tryParse(_quantity.text.trim());
  num? get _price => num.tryParse(_targetPrice.text.trim());

  /// Mirrors the server's rules so the button only lights up for a request
  /// it will accept.
  bool get _valid {
    final qty = _qty;
    if (qty == null || qty < 1 || qty > 100000) return false;
    if (_targetPrice.text.trim().isNotEmpty && (_price ?? 0) <= 0) {
      return false;
    }
    return _productId != null || _requirements.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_valid || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final sent = await ref.read(rfqRepositoryProvider).submit(
            productId: _productId,
            quantity: _qty!,
            requirements: _requirements.text,
            targetPrice: _targetPrice.text.trim().isEmpty ? null : _price,
          );
      if (mounted) Navigator.pop(context, sent);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.isNotFound && _productId != null) {
          // The product went offline — let it go as requirements-only.
          _productId = null;
          _error = 'This product is no longer listed. Describe what you '
              'need below and send it as a general enquiry.';
        } else {
          _error = orderErrorMessage(e);
        }
      });
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
    final name = widget.productName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _productId != null && name != null
              ? 'Tell us how many “$name” you need. Our team will call or '
                  'email you with dealer pricing.'
              : 'Tell us what you need. Our team will call or email you with '
                  'dealer pricing.',
          style: context.text.bodySecondary,
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Quantity',
          hint: 'e.g. 50',
          controller: _quantity,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          maxLength: 6,
          enabled: !_busy,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          label: 'Requirements',
          hint: 'Delivery location, deadline, specs, GST invoice…',
          controller: _requirements,
          maxLines: 4,
          maxLength: 2000,
          optional: _productId != null,
          enabled: !_busy,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpacing.md),
        AppTextField(
          // ponytail: the API doesn't say per unit or total; we ask for per
          // unit so staff read it one way.
          label: 'Target price per unit (₹)',
          hint: 'e.g. 4200',
          controller: _targetPrice,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          optional: true,
          enabled: !_busy,
          onChanged: (_) => setState(() {}),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.smd),
          InlineBanner(message: _error!, tone: Tone.error),
        ],
        const SizedBox(height: AppSpacing.lg),
        AppButton(
          label: 'Send request',
          icon: Icons.request_quote_rounded,
          loading: _busy,
          onPressed: _valid ? _submit : null,
        ),
      ],
    );
  }
}

/// "My quote requests" (`GET /rfq`).
class QuoteRequestsScreen extends ConsumerWidget {
  const QuoteRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final requests = ref.watch(myQuoteRequestsProvider);
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppTopBar(
        title: 'Bulk quote requests',
        actions: [
          AppIconButton(
            icon: Icons.add_rounded,
            tooltip: 'New request',
            onPressed: () => showQuoteRequestSheet(context),
          ),
        ],
      ),
      body: requests.when(
        skipLoadingOnRefresh: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => ErrorState(
          error: err,
          message: orderErrorMessage(err),
          onRetry: () => ref.invalidate(myQuoteRequestsProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyState(
                icon: Icons.request_quote_rounded,
                title: 'No quote requests yet',
                message: 'Buying for a farm or project? Ask for dealer '
                    'pricing on larger quantities.',
                actionLabel: 'Request a quote',
                onAction: () => showQuoteRequestSheet(context),
              )
            : RefreshIndicator(
                color: c.primary,
                onRefresh: () => ref.refresh(myQuoteRequestsProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.gutter),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Hairline(),
                  itemBuilder: (context, i) => _QuoteRow(request: list[i]),
                ),
              ),
      ),
    );
  }
}

class _QuoteRow extends StatelessWidget {
  const _QuoteRow({required this.request});

  final QuoteRequest request;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final tone = switch (r.status) {
      'CONTACTED' => Tone.success,
      'CLOSED' => Tone.neutral,
      _ => Tone.info,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.smd + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.productTitle ?? 'General enquiry',
                  style: context.text.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusPill(label: r.statusLabel, tone: tone, dot: true),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            [
              'Qty ${r.quantity}',
              if (r.targetPrice != null)
                'target ${formatInr(r.targetPrice!)}/unit',
              formatOrderDate(r.createdAt),
            ].join(' · '),
            style: context.text.captionMuted,
          ),
          if (r.requirements != null && r.requirements!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              r.requirements!,
              style: context.text.bodySecondary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}
