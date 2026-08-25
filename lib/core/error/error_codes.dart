/// Server error codes, agreed with the backend team.
///
/// The server returns these in `error.code`; the client switches on them
/// rather than on HTTP status alone or on message text.
abstract final class ErrorCodes {
  // Auth — OTP
  static const String otpInvalid = 'OTP_INVALID';
  static const String otpExpired = 'OTP_EXPIRED';
  static const String otpAttemptsExceeded = 'OTP_ATTEMPTS_EXCEEDED';
  static const String otpResendTooSoon = 'OTP_RESEND_TOO_SOON';

  // Auth — session
  static const String tokenExpired = 'TOKEN_EXPIRED';
  static const String tokenRevoked = 'TOKEN_REVOKED';
  static const String invalidCredentials = 'INVALID_CREDENTIALS';
  static const String accountBlocked = 'ACCOUNT_BLOCKED';
  static const String phoneAlreadyRegistered = 'PHONE_ALREADY_REGISTERED';

  // Generic
  static const String validationError = 'VALIDATION_ERROR';
  static const String notFound = 'NOT_FOUND';
  static const String forbidden = 'FORBIDDEN';
  static const String rateLimited = 'RATE_LIMITED';

  // Commerce
  static const String outOfStock = 'OUT_OF_STOCK';
  static const String priceChanged = 'PRICE_CHANGED';
  static const String cartEmpty = 'CART_EMPTY';
  static const String pincodeNotServiceable = 'PINCODE_NOT_SERVICEABLE';
  static const String couponInvalid = 'COUPON_INVALID';
  static const String paymentFailed = 'PAYMENT_FAILED';
}
