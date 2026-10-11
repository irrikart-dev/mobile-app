import 'package:flutter_test/flutter_test.dart';
import 'package:irrikart/core/auth/auth_service.dart';
import 'package:irrikart/core/auth/auth_validators.dart';
import 'package:irrikart/screens/profile/views/account_providers.dart';

void main() {
  group('Indian mobile numbers', () {
    test('accepts 10 digits starting 6-9, with or without +91 / 0', () {
      expect(AuthValidators.indianMobileDigits('9876543210'), '9876543210');
      expect(
        AuthValidators.indianMobileDigits('+91 98765 43210'),
        '9876543210',
      );
      expect(AuthValidators.indianMobileDigits('09876543210'), '9876543210');
      expect(AuthValidators.indianMobileDigits('6000000000'), '6000000000');
    });

    test('rejects wrong length or leading digit', () {
      expect(AuthValidators.indianMobileDigits('5876543210'), isNull);
      expect(AuthValidators.indianMobileDigits('987654321'), isNull);
      expect(AuthValidators.phoneError(''), isNotNull);
      expect(AuthValidators.phoneError('98765'), contains('10 digits'));
      expect(AuthValidators.phoneError('1234567890'), contains('6, 7, 8 or 9'));
      expect(AuthValidators.phoneError('9876543210'), isNull);
    });

    test('formats for display and E.164', () {
      expect(AuthValidators.toE164('9876543210'), '+919876543210');
      expect(AuthValidators.formatPhone('+919876543210'), '+91 98765 43210');
      expect(AuthValidators.formatPhone('+14155550100'), '+14155550100');
    });

    test('input formatter strips a pasted country code', () {
      const f = IndianMobileInputFormatter();
      TextEditingValue paste(String s) => f.formatEditUpdate(
            TextEditingValue.empty,
            TextEditingValue(text: s),
          );
      expect(paste('+91 98765 43210').text, '9876543210');
      expect(paste('09876543210').text, '9876543210');
      expect(paste('98a76').text, '9876');
    });
  });

  group('email + password', () {
    test('email', () {
      expect(AuthValidators.emailError(''), isNotNull);
      expect(AuthValidators.emailError('ravi@'), isNotNull);
      expect(AuthValidators.emailError(' ravi@farm.in '), isNull);
    });

    test('new password needs 8+ chars and a matching confirm', () {
      expect(AuthValidators.newPasswordError('short'), isNotNull);
      expect(AuthValidators.newPasswordError('longenough'), isNull);
      expect(AuthValidators.confirmPasswordError('a', 'b'), isNotNull);
      expect(
        AuthValidators.confirmPasswordError('pass1234', 'pass1234'),
        isNull,
      );
    });

    test('name is 1-100 trimmed chars; optional on sign-up', () {
      expect(AuthValidators.nameError('  '), isNotNull);
      expect(AuthValidators.nameError('  ', optional: true), isNull);
      expect(AuthValidators.nameError('R'), isNull);
      expect(AuthValidators.nameError('x' * 101), isNotNull);
      expect(AuthValidators.nameError('x' * 100), isNull);
    });
  });

  test('Firebase error codes map to friendly copy', () {
    expect(
      AuthService.messageFor('operation-not-allowed'),
      contains('isn’t enabled'),
    );
    expect(
      AuthService.messageFor('invalid-credential'),
      contains('don’t match'),
    );
    expect(AuthService.messageFor('wrong-password'), contains('don’t match'));
    expect(AuthService.messageFor('user-not-found'), contains('No account'));
    expect(
      AuthService.messageFor('email-already-in-use'),
      contains('already exists'),
    );
    expect(AuthService.messageFor('weak-password'), contains('stronger'));
    expect(AuthService.messageFor('too-many-requests'), contains('Too many'));
    expect(
      AuthService.messageFor('network-request-failed'),
      contains('internet'),
    );
    expect(
      AuthService.messageFor('invalid-verification-code'),
      contains('code'),
    );
    expect(AuthService.messageFor('quota-exceeded'), contains('later'));
    expect(AuthService.messageFor('something-new'), contains('try again'));
  });

  test('initials fall back to IK for a phone-number name', () {
    expect(accountInitials('Ravi Kumar'), 'RK');
    expect(accountInitials('+91 98765 43210'), 'IK');
  });
}
