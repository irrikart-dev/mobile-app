import 'package:flutter/material.dart';

import '../../core/theme/tokens/radius_tokens.dart';
import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import 'app_button.dart';

/// Opens the app's standard bottom sheet: drag handle, optional title row
/// with a close button, keyboard-aware padding, and a max height of 90% of
/// the screen (content scrolls beyond that).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  bool scrollable = true,
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(
    AppSpacing.gutter,
    0,
    AppSpacing.gutter,
    AppSpacing.md,
  ),
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true,
    shape: const RoundedRectangleBorder(borderRadius: AppRadius.sheetTop),
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.9;
      final body = Padding(padding: padding, child: builder(sheetContext));
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Handle(),
                if (title != null) _SheetTitle(title: title),
                if (scrollable)
                  Flexible(child: SingleChildScrollView(child: body))
                else
                  Flexible(child: body),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: context.colors.borderStrong,
          borderRadius: AppRadius.pillAll,
        ),
      ),
    );
  }
}

class _SheetTitle extends StatelessWidget {
  const _SheetTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.gutter,
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.h3)),
          AppIconButton(
            icon: Icons.close_rounded,
            tooltip: 'Close',
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
