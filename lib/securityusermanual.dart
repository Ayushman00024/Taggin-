import 'package:flutter/material.dart';

class SecurityUserManualScreen extends StatelessWidget {
  const SecurityUserManualScreen({Key? key}) : super(key: key);

  Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 6.0),
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 20,
        color: Colors.lightBlueAccent,
      ),
    ),
  );

  Widget sectionText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white70,
        height: 1.5,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Taggin Security Manual',
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 10),
        child: ListView(
          physics: const BouncingScrollPhysics(),
          children: [
            sectionTitle('1. Google Sign-In Only'),
            sectionText(
                "Taggin uses Google Sign-In exclusively for user authentication. "
                    "No passwords or manual login are used. Google’s OAuth2.0 system "
                    "securely manages identity verification, and user credentials "
                    "(email, UID) are handled only by Google."),

            sectionTitle('2. Profile Visibility Rules'),
            sectionText(
                "A user’s profile appears only within the college or university "
                    "they selected during registration and among nearby users within "
                    "Taggin’s set radius. Profiles are not globally visible unless "
                    "users choose to post publicly. Users have full control over their visibility settings."),

            sectionTitle('3. Messaging Rules'),
            sectionText(
                "Private messaging is only possible after both users accept each "
                    "other’s friend request. No one can message another user directly "
                    "without mutual acceptance. Group or local chats are available only "
                    "to verified users in the same physical location."),

            sectionTitle('4. Data Storage and Protection'),
            sectionText(
                "All user data (profiles, posts, messages, likes) is stored securely "
                    "on Google Firebase. Firebase provides end-to-end encryption, "
                    "SSL/TLS for data transfer, and AES-256 encryption at rest. "
                    "Only authenticated users can access their own data. "
                    "Taggin does not sell or share data with third parties."),

            sectionTitle('5. User-Controlled Features'),
            sectionText(
                "Users can delete comments on their own posts, edit usernames, or "
                    "delete their entire account at any time. Account deletion "
                    "permanently removes all data (posts, messages, likes, etc.) from Firebase servers."),

            sectionTitle('6. Permission-Based Access'),
            sectionText(
                "Taggin requests permissions only when required for functionality:\n\n"
                    "📍 Location — To show nearby users and local posts (used only while the app is active).\n"
                    "🔔 Notifications — To send real-time updates like likes or friend requests.\n"
                    "📷 Media/Camera — For uploading chosen photos or videos.\n\n"
                    "No background tracking, automatic access, or hidden data collection occurs."),

            sectionTitle('7. Data Encryption & Transfer'),
            sectionText(
                "Every request between the Taggin app and Firebase uses HTTPS. "
                    "Sensitive data like messages and location is encrypted before storage. "
                    "Firestore Security Rules restrict all reads and writes based on the user’s UID."),

            sectionTitle('8. Account and Identity Verification'),
            sectionText(
                "Every user must authenticate through a verified Google account. "
                    "No anonymous or guest accounts exist. This ensures accountability "
                    "and reduces fake or spam accounts."),

            sectionTitle('9. Content & Interaction Safety'),
            sectionText(
                "Users can report inappropriate behavior or content directly in the app. "
                    "All reports are reviewed and may result in post removal or account suspension. "
                    "Users can also delete uncomfortable comments on their own posts."),

            sectionTitle('10. Data Retention and Deletion'),
            sectionText(
                "When a user deletes their account, all personal data (posts, chats, likes, etc.) "
                    "is permanently erased from Firebase. Cached or backup data is cleared within 30 days."),

            sectionTitle('11. User Privacy Protections'),
            sectionText(
                "Exact locations are never shared publicly. Visibility is based on approximate "
                    "coordinates only when a user chooses to appear nearby. Taggin follows "
                    "privacy-by-design principles with minimal data collection and full transparency."),

            sectionTitle('12. Support and Reporting'),
            sectionText(
                "For privacy or security issues, users can email:\n\n"
                    "📩 tagginteam@gmail.com\n\n"
                    "All inquiries related to data deletion, account recovery, or policy concerns "
                    "are handled securely and promptly."),

            sectionTitle('13. Compliance'),
            sectionText(
                "Taggin complies with Google Play Developer Policy, GDPR (General Data Protection Regulation), "
                    "and India’s DPDP (Digital Personal Data Protection Act). All permissions are declared clearly, "
                    "and user consent is always required before access."),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
