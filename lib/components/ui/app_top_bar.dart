import 'package:flutter/material.dart';

import '../../core/theme/tokens/spacing_tokens.dart';
import '../../core/utils/context_ext.dart';
import 'app_button.dart';

/// The app bar every screen uses.
///
/// * Pushed screens get a back button automatically.
/// * [large] is for tab roots (Cart, Orders, Account, Categories): a bigger
///   left-aligned title with an optional [subtitle] underneath.
/// * A hairline appears under the bar once content scrolls beneath it.
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  const AppTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.actions = const [],
    this.large = false,
    this.showBack,
    this.onBack,
    this.bottom,
    this.backgroundColor,
    this.centerTitle = false,
  });

  final String? title;
  final String? subtitle;
  final List<Widget> actions;
  final bool large;

  /// Defaults to `Navigator.canPop`.
  final bool? showBack;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final bool centerTitle;

  double get _toolbarHeight => large ? (subtitle == null ? 68 : 76) : 56;

  @override
  Size get preferredSize =>
      Size.fromHeight(_toolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canPop = showBack ?? ModalRoute.of(context)?.canPop ?? false;

    final titleWidget = title == null
        ? null
        : Column(
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: large ? context.text.h1 : context.text.h3,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.caption,
                ),
              ],
            ],
          );

    return AppBar(
      toolbarHeight: _toolbarHeight,
      backgroundColor: backgroundColor ?? c.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      centerTitle: centerTitle,
      automaticallyImplyLeading: false,
      titleSpacing: canPop ? 0 : AppSpacing.gutter,
      leadingWidth: canPop ? 56 : 0,
      leading: canPop
          ? Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: AppIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: 'Back',
                onPressed: onBack ?? () => Navigator.maybePop(context),
              ),
            )
          : null,
      title: titleWidget,
      actions: [
        ...actions,
        const SizedBox(width: AppSpacing.sm),
      ],
      bottom: bottom,
    );
  }
}
