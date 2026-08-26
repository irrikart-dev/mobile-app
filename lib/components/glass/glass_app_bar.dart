import 'package:flutter/material.dart';

import '../../core/theme/tokens/spacing_tokens.dart';
import 'glass_container.dart';

/// A frosted app bar. Content scrolls beneath and blurs through it, rather
/// than disappearing behind a solid bar.
///
/// Use as `Scaffold(extendBodyBehindAppBar: true, appBar: GlassAppBar(...))`
/// — `extendBodyBehindAppBar` is required or the body never draws behind the
/// bar and there is nothing to blur.
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GlassAppBar({
    super.key,
    this.title,
    this.leading,
    this.actions = const [],
    this.centerTitle = false,
    this.bottom,
  });

  final Widget? title;
  final Widget? leading;
  final List<Widget> actions;
  final bool centerTitle;

  /// Extra content below the title row (e.g. a search field), still inside
  /// the glass surface.
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return GlassContainer(
      blur: 20,
      borderRadius: BorderRadius.zero,
      tintOpacity: 0.7,
      borderOpacity: 0,
      padding: EdgeInsets.only(top: topPadding),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: kToolbarHeight,
              child: Row(
                children: [
                  if (leading != null) leading! else const SizedBox(width: 8),
                  Expanded(
                    child: centerTitle
                        ? Center(child: title ?? const SizedBox())
                        : (title ?? const SizedBox()),
                  ),
                  ...actions,
                ],
              ),
            ),
            if (bottom != null) bottom!,
          ],
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom != null ? kToolbarHeight * 0.7 : 0),
  );
}
