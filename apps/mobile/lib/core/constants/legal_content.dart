/// In-app legal copy. Replace with your own policy before publishing a build.
abstract final class LegalContent {
  static const privacyTitle = 'Privacy Policy';
  static const privacyUpdated = 'Template: replace before publishing';

  static const privacyBody = '''
This is a self-hosted CLIVORA Community deployment. The organisation that operates this deployment is the data controller and is responsible for its privacy policy.

Operators: replace this text in lib/core/constants/legal_content.dart and legal_documents.dart (and the matching web pages) with your own policy before publishing the app. Describe what personal data you collect (account details, client and invoice records, messages, files), where it is stored (your Supabase project), who you share it with, how long you keep it, and how users can export or delete their data.
''';

  static const termsTitle = 'Terms of Service';
  static const termsUpdated = 'Template: replace before publishing';

  static const termsBody = '''
This is a self-hosted CLIVORA Community deployment, provided under the GNU Affero General Public License v3.0. The organisation that operates this deployment sets its own terms of service.

Operators: replace this text in lib/core/constants/legal_content.dart and legal_documents.dart (and the matching web pages) with your own terms before publishing the app.
''';
}
