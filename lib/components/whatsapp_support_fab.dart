import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';

import '../core/auth/auth_service.dart';
import '../core/theme/tokens/spacing_tokens.dart';
import '../core/utils/whatsapp_launcher.dart';
import '../entry_point_tab.dart';
import '../route/route_constants.dart';
import '../route/route_tracker.dart';

/// WhatsApp's own brand green — the one hard-coded colour outside the theme,
/// because the button must read as "WhatsApp", not as an IrriKart action.
const _whatsAppGreen = Color(0xFF25D366);

/// Routes where a floating button would cover the screen's primary action or
/// make no sense (no account yet).
const _hiddenOn = {
  onbordingScreenRoute,
  logInScreenRoute,
  signUpScreenRoute,
  productDetailsScreenRoute,
  cartScreenRoute,
  checkoutScreenRoute,
  orderProcessingScreenRoute,
  thanksForOrderScreenRoute,
  addNewAddressesScreenRoute,
  searchScreenRoute,
};

/// Index of the Cart tab inside the shell — its sticky checkout bar sits
/// where the button would.
const _cartTabIndex = 2;

/// Floating WhatsApp support button, mounted once above the navigator (see
/// `IrriKartApp`'s `MaterialApp.builder`). Route-aware: hidden before sign-in,
/// on screens with a bottom CTA, and while any sheet or dialog is open.
class WhatsAppSupportFab extends ConsumerWidget {
  const WhatsAppSupportFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(isSignedInProvider);
    final tab = ref.watch(entryTabIndexProvider);
    if (!signedIn) return const SizedBox.shrink();

    return ListenableBuilder(
      listenable: Listenable.merge([currentRouteName, openPopupCount]),
      builder: (context, _) {
        final route = currentRouteName.value;
        final inShell = route == entryPointScreenRoute;
        final hidden = _hiddenOn.contains(route) ||
            openPopupCount.value > 0 ||
            (inShell && tab == _cartTabIndex);
        final inset = MediaQuery.paddingOf(context).bottom;
        final bottom =
            inset + (inShell ? AppSpacing.navBarHeight : 0) + AppSpacing.md;

        return Positioned(
          right: AppSpacing.md,
          bottom: bottom,
          child: AnimatedScale(
            scale: hidden ? 0 : 1,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: IgnorePointer(
              ignoring: hidden,
              child: Semantics(
                button: true,
                label: 'Chat with IrriKart support on WhatsApp',
                child: Material(
                  color: _whatsAppGreen,
                  shape: const CircleBorder(),
                  elevation: 3,
                  shadowColor: Colors.black38,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => openWhatsAppSupport(context),
                    child: const SizedBox.square(
                      dimension: 52,
                      child: Center(
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedWhatsapp,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
