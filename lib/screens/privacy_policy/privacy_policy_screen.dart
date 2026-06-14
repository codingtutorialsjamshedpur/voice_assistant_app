import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../routes/app_routes.dart';

import '../../services/storage_service.dart';
import '../../shared/widgets/shared_widgets.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _isAccepted = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (!_hasScrolledToBottom &&
          _scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 50) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    });

    // Check if enough content exists to warrant scrolling; if not, auto-enable.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent == 0) {
        setState(() {
          _hasScrolledToBottom = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onAcceptAndContinue() async {
    if (_isAccepted && _hasScrolledToBottom) {
      await StorageService.to.setPrivacyAccepted(true);
      Get.offAllNamed(AppRoutes.authentication);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine button enabled state
    final bool canProceed = _hasScrolledToBottom && _isAccepted;

    return AppBackground(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // Header
              const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                        color: Colors.black26,
                        offset: Offset(0, 2),
                        blurRadius: 4),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please review carefully before proceeding',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Scrollable Policy Content inside Glass Container
              Expanded(
                child: GlassContainer(
                  padding: const EdgeInsets.all(0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: RawScrollbar(
                      controller: _scrollController,
                      thumbColor: const Color(0xFFFFB2EE),
                      radius: const Radius.circular(8),
                      thickness: 6,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(24.0),
                        child: const Text(
                          _privacyPolicyText, // See below
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Acceptance Checkbox
              GlassContainer(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Checkbox(
                      value: _isAccepted,
                      onChanged: _hasScrolledToBottom
                          ? (value) {
                              setState(() {
                                _isAccepted = value ?? false;
                              });
                            }
                          : null,
                      activeColor: const Color(0xFFFFB2EE),
                      checkColor: Colors.black,
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: _hasScrolledToBottom
                            ? () {
                                setState(() {
                                  _isAccepted = !_isAccepted;
                                });
                              }
                            : null,
                        child: Text(
                          'I have read and accept the privacy policy.',
                          style: TextStyle(
                            color: _hasScrolledToBottom
                                ? Colors.black
                                : Colors.black54,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Accept & Continue Button
              ElevatedButton(
                onPressed: canProceed ? _onAcceptAndContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB2EE),
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: canProceed ? 4 : 0,
                ),
                child: const Text(
                  'Accept & Continue',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  static const String _privacyPolicyText = '''
Privacy Policy for CTJ Voice Chat v1.0

Developer: Sourav Kumar
Last Updated: May 2026

1. Introduction
Welcome to CTJ Voice Chat v1.0 ("Application")! We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you about how we collect, use, and store your information when you use our application.

2. Information We Collect

2.1 User Authentication & Profile Data
When you sign in via Google Authentication, we collect and store:
- Name (from your Google account)
- Email address (from your Google account)
- User ID (provided by authentication provider)
- Profile image URL (from your Google account, if available)
We collect ONLY these fields. No other personal information is automatically extracted.

2.2 Location & Weather Data
To provide location-based features (location display, local weather, and Air Quality Index), we require:
- GPS coordinates (latitude & longitude) - collected with your explicit permission
- Location name (reverse-geocoded from GPS coordinates)
- Current temperature at your location
- Air Quality Index (AQI) data for your location
GPS must be enabled by the user to access these features. This data is retrieved in real-time and is NOT persistently stored on our servers.

2.3 Voice & Audio Data
- Voice input is processed locally on your device using Speech-to-Text (STT) technology
- Voice input is temporarily processed to generate responses but is NOT recorded or stored on our servers
- Audio responses generated by Text-to-Speech (TTS) are temporarily generated and not saved
- User-created voice recordings in Voice Studio are stored locally on your device only

2.4 Chat History & Conversation Data
- All chat messages and conversation history are stored exclusively on your local device
- Conversation data is NOT uploaded to our servers
- You can view, delete, or clear chat history anytime through the app's History or Settings screens
- Deleted data is permanently removed from your device

2.5 Application Settings & Preferences
- Theme preferences (dark/light mode)
- Language selection
- Wallpaper preferences
- Privacy settings selections
- Alarm and reminder configurations
All settings are stored locally on your device.

3. How We Use Your Data

3.1 Profile Data Usage
- To display your name and email on your profile screen
- To authenticate and maintain your session within the application
- To personalize your experience with the AI voice assistant

3.2 Location & Weather Data Usage
- To display your current location on the home screen/top panel
- To show real-time weather information
- To provide Air Quality Index (AQI) information for health awareness
- Location data is fetched in real-time and used only for display purposes

3.3 Voice & Audio Data Usage
- To process your voice commands and provide AI-generated responses
- To improve speech recognition accuracy for your personal experience
- Voice data is processed locally and never transmitted to external servers for storage

3.4 Chat History Usage
- To enable you to review past conversations
- To provide conversation continuity across sessions
- For your personal reference and record-keeping

3.5 General Usage
- We do NOT sell, trade, or rent your personal information to third parties
- We do NOT use your data for marketing or advertising purposes
- We do NOT share your data with external analytics services

4. What Data is Stored on Your Device vs. Our Servers

4.1 Data Stored Locally on Your Device (ONLY):
- Chat history and conversation logs
- Voice recordings created in Voice Studio
- Alarms and reminders
- User profile information (name, email from authentication)
- Application preferences and settings
- Wallpaper selections

4.2 Data Stored on Our Servers (Supabase):
- API Keys and configuration secrets (for app functionality and API management)
- Wallpaper catalog metadata (available wallpaper images)
We maintain strict access controls and encryption for all server-side data.

4.3 Data Never Stored:
- Voice input/STT audio
- Real-time location coordinates (fetched on-demand only)
- TTS-generated audio responses

5. Third-Party Services

5.1 Google Authentication
We use Google Sign-In via Supabase for secure authentication. Your Google account data (name, email, profile picture) is retrieved only during sign-in. Please refer to Google's Privacy Policy for how they handle your data.

5.2 Location Services
Location data is obtained through your device's GPS and processed using OpenStreetMap's Nominatim service for reverse geocoding (converting coordinates to location names). This data is not stored.

5.3 Weather & AQI Data
Weather and Air Quality Index data is fetched from public APIs in real-time and displayed to you. This data is not stored on your device or our servers.

5.4 Voice Processing
Voice input is processed using on-device Speech-to-Text technology and AI models. Voice data is NOT transmitted to external voice processing servers for storage.

6. Your Rights & Data Control

You have full control over your data:
- You can view your profile information in the Profile screen
- You can delete your chat history anytime in the History screen
- You can reset all app settings in the Settings screen
- You can disable GPS location services in your device settings
- You can manage privacy preferences in the Privacy Settings screen
- You can sign out and delete your profile data by resetting the application

7. Data Security

All personal data stored on your local device is protected by your device's built-in security measures:
- Data is stored using secure local storage (GetStorage with encryption)
- Server-side data (API keys, wallpaper metadata) is stored in a Supabase-managed PostgreSQL database with industry-standard security
- We do not transmit your chat history or personal data over unencrypted connections
- Any data transmitted to our servers uses HTTPS encryption

8. Children's Privacy

This application may be used by children with parental consent. We do not knowingly collect additional personal information from children. Parents can control location permissions and privacy settings through their device settings.

9. Permissions Required

The application requires the following permissions:
- GPS Location: To display location, weather, and AQI information
- Microphone: To process voice input and record custom voice samples
- File Storage: To save chat history, preferences, and custom recordings locally
- Audio: To play audio responses and sound effects
- Internet: To fetch weather data and authenticate with Google

You can grant or revoke these permissions at any time in your device's Settings.

10. Changes to This Privacy Policy

We may update this Privacy Policy periodically to reflect changes in our practices or for other operational, legal, or regulatory reasons. We will notify you of significant changes by updating the "Last Updated" date and displaying a notice in the application when you next open it.

11. Contact Us

If you have any questions about this Privacy Policy or our privacy practices, please contact:

Developer: Sourav Kumar
Location: Jamshedpur, India
Expertise: Flutter Mobile Application Development

For support and inquiries, please refer to the About screen within the application for contact options.

12. Data Retention

- Profile data (name, email) is retained as long as your account is active
- Chat history is retained until you manually delete it
- Local settings and preferences are retained until you reset the application
- Upon app uninstall, all local data is automatically removed from your device
- Server-side data (API keys, wallpaper metadata) is retained to maintain app functionality

13. Compliance

This Privacy Policy complies with standard mobile application privacy practices and is designed to be transparent about data collection and usage. We are committed to protecting your privacy and ensuring you have a positive experience with CTJ Voice Chat v1.0.

Scroll down to acknowledge that you have read and understood this policy.
''';
}
