/// Retail/dealer support contact info.
///
/// SET ME: replace with IrriKart's real WhatsApp Business number
/// (international format, digits only, no `+`) before shipping this build.
abstract final class SupportConfig {
  static const whatsAppNumber = '919711091823';

  static const whatsAppDefaultMessage =
      'Hi IrriKart, I have a question about your products.';

  /// Public legal pages, hosted by the web-frontend app. Also linked from the
  /// Google Play listing (privacy policy + account deletion URL).
  static const _legalOrigin = 'https://web-frontend-alpha-two.vercel.app';
  static const termsUrl = '$_legalOrigin/terms';
  static const privacyUrl = '$_legalOrigin/privacy';
  static const deleteAccountUrl = '$_legalOrigin/delete-account';
}
