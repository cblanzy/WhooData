// lib/config/app_brand.dart
class AppBrand {
  static const appName =
      String.fromEnvironment('APP_NAME', defaultValue: 'WhooDat(a)?');

  static const company =
      String.fromEnvironment('COMPANY', defaultValue: 'Your Company, LLC');
  static const supportEmail = String.fromEnvironment(
    'SUPPORT_EMAIL',
    defaultValue: 'support@example.com',
  );
  static const website =
      String.fromEnvironment('WEBSITE', defaultValue: 'https://example.com');
  static const privacyUrl = String.fromEnvironment(
    'PRIVACY_URL',
    defaultValue: 'https://example.com/privacy',
  );
  static const termsUrl = String.fromEnvironment(
    'TERMS_URL',
    defaultValue: 'https://example.com/terms',
  );

  static const brandKey =
      String.fromEnvironment('BRAND_KEY', defaultValue: 'default');
  static String logoAsset([double scale = 1]) =>
      'assets/branding/$brandKey/logo.png';
}
