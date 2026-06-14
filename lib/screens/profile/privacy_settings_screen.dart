import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../services/storage_service.dart';
import '../../shared/widgets/shared_widgets.dart';
import '../../shared/theme/app_colors.dart';
import '../../shared/theme/responsive.dart';
import '../../shared/theme/responsive_widgets.dart';
import '../../shared/haptic/haptic_feedback.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  // Privacy settings state
  bool _shareUsageData = false;
  bool _allowVoiceRecording = true;
  bool _storeChatHistory = true;
  bool _personalizedSuggestions = true;
  bool _locationServices = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    setState(() {
      _shareUsageData = StorageService.to.read('privacy_share_usage') ?? false;
      _allowVoiceRecording =
          StorageService.to.read('privacy_voice_recording') ?? true;
      _storeChatHistory =
          StorageService.to.read('privacy_chat_history') ?? true;
      _personalizedSuggestions =
          StorageService.to.read('privacy_personalized') ?? true;
      _locationServices = StorageService.to.read('privacy_location') ?? false;
    });
  }

  Future<void> _saveSetting(String key, bool value) async {
    await StorageService.to.write('privacy_$key', value);
    if (value) {
      AppHaptic.toggleOn();
    } else {
      AppHaptic.toggleOff();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: context.r.all(24),
              child: Row(
                children: [
                  Semantics(
                    label: 'Go back',
                    button: true,
                    child: GestureDetector(
                      onTap: () {
                        Get.back();
                      },
                      child: Container(
                        padding: context.r.all(8),
                        child: Icon(
                          Icons.arrow_back,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                  ),
                    const RSizedBox(w: 16),
                    Expanded(
                    child: Text(
                      'Privacy Settings',
                      style: TextStyle(
                        fontSize: context.r.sp(24),
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Settings List
            Expanded(
              child: SingleChildScrollView(
                padding: context.r.symmetric(h: 24, v: 0),
                child: Column(
                  children: [
                    GlassContainer(
                      padding: context.r.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Data & Privacy',
                            style: TextStyle(
                              fontSize: context.r.sp(18),
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const RSizedBox(h: 8),
                          Text(
                            'Control how your data is used and shared',
                            style: TextStyle(
                              fontSize: context.r.sp(13),
                              color: const Color(0xFF5A3E54),
                            ),
                          ),
                          const RSizedBox(h: 20),
                          _buildToggleItem(
                            icon: Icons.analytics_outlined,
                            title: 'Share Usage Data',
                            subtitle:
                                'Help improve the app by sharing anonymous usage statistics',
                            value: _shareUsageData,
                            onChanged: (value) {
                              setState(() => _shareUsageData = value);
                              _saveSetting('share_usage', value);
                            },
                          ),
                          const Divider(height: 32),
                          _buildToggleItem(
                            icon: Icons.mic_outlined,
                            title: 'Voice Recording',
                            subtitle:
                                'Allow the app to record voice for speech recognition',
                            value: _allowVoiceRecording,
                            onChanged: (value) {
                              setState(() => _allowVoiceRecording = value);
                              _saveSetting('voice_recording', value);
                            },
                          ),
                          const Divider(height: 32),
                          _buildToggleItem(
                            icon: Icons.history_outlined,
                            title: 'Store Chat History',
                            subtitle:
                                'Save your conversations for future reference',
                            value: _storeChatHistory,
                            onChanged: (value) {
                              setState(() => _storeChatHistory = value);
                              _saveSetting('chat_history', value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const RSizedBox(h: 16),
                    GlassContainer(
                      padding: context.r.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Personalization',
                            style: TextStyle(
                              fontSize: context.r.sp(18),
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary(context),
                            ),
                          ),
                          const RSizedBox(h: 8),
                          Text(
                            'Customize your experience',
                            style: TextStyle(
                              fontSize: context.r.sp(13),
                              color: const Color(0xFF5A3E54),
                            ),
                          ),
                          const RSizedBox(h: 20),
                          _buildToggleItem(
                            icon: Icons.lightbulb_outline,
                            title: 'Personalized Suggestions',
                            subtitle:
                                'Get AI recommendations based on your interests',
                            value: _personalizedSuggestions,
                            onChanged: (value) {
                              setState(() => _personalizedSuggestions = value);
                              _saveSetting('personalized', value);
                            },
                          ),
                          const Divider(height: 32),
                          _buildToggleItem(
                            icon: Icons.location_on_outlined,
                            title: 'Location Services',
                            subtitle:
                                'Allow access to location for local news and weather',
                            value: _locationServices,
                            onChanged: (value) {
                              setState(() => _locationServices = value);
                              _saveSetting('location', value);
                            },
                          ),
                        ],
                      ),
                    ),
                    const RSizedBox(h: 16),
                    // Privacy Policy Button
                    Semantics(
                      label: 'View privacy policy',
                      button: true,
                      child: GestureDetector(
                        onTap: () {
                          _showPrivacyPolicy();
                        },
                        child: GlassContainer(
                          padding: context.r.all(16),
                          child: Row(
                          children: [
                            Container(
                              width: context.r.scale(40),
                              height: context.r.scale(40),
                              decoration: BoxDecoration(
                                color: Colors.blue[100]!.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.policy_outlined,
                                color: Colors.blue[600],
                                size: context.r.scale(20),
                              ),
                            ),
                            const RSizedBox(w: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Privacy Policy',
                                  style: TextStyle(
                                    fontSize: context.r.sp(16),
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary(context),
                                  ),
                                ),
                                Text(
                                  'Read our privacy policy',
                                  style: TextStyle(
                                    fontSize: context.r.sp(12),
                                      color: AppColors.textSecondary(context),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios,
                              size: context.r.scale(16),
                              color: Colors.grey[400],
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),
                    const RSizedBox(h: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Builder(
      builder: (context) => Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: context.r.scale(40),
            height: context.r.scale(40),
            decoration: BoxDecoration(
              color: value
                  ? const Color(0xFFFFB2EE).withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                key: ValueKey('icon_$value'),
                color: value
                    ? const Color(0xFFFF69B4)
                    : Colors.grey,
                size: context.r.scale(20),
              ),
            ),
          ),
          const RSizedBox(w: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: context.r.sp(15),
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: context.r.sp(12),
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFFFB2EE),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  void _showPrivacyPolicy() {
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: Get.height * 0.8,
          ),
          padding: context.r.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(context.r.scale(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (ctx) => Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: context.r.sp(20),
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(ctx),
                  ),
                ),
              ),
              const RSizedBox(h: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Text(
                    '''PRIVACY POLICY FOR CTJ VOICE CHAT v1.0

Effective Date: June 2026 | Last Updated: June 2026
Developer: Sourav Kumar | Version: 1.0

1. INTRODUCTION

Welcome to CTJ Voice Chat v1.0. We are committed to protecting your privacy and ensuring transparency about data collection and usage. This Privacy Policy applies to all users of the Application.

2. INFORMATION WE COLLECT

Authentication & Profile Data:
• Name, email address, user ID, and profile image (from Google Authentication only)

Location & Weather Data (Optional):
• GPS coordinates (requires explicit permission)
• Location name, temperature, and Air Quality Index (real-time only)

Voice & Audio Data:
• Voice commands processed locally via Speech-to-Text
• Voice recordings in Voice Studio (stored locally only)

Chat & Conversation Data:
• All chat messages stored exclusively on your device

Application Settings & Preferences:
• Theme, language, wallpaper, and privacy preferences stored locally

3. WHERE YOUR DATA IS STORED

✓ Stored on Your Device Only:
  - Chat history and conversations
  - Voice recordings
  - Alarms and reminders
  - Settings and preferences

✓ Stored on Our Servers (Encrypted):
  - API keys and configuration data
  - Wallpaper catalog metadata

✗ Never Stored:
  - Voice audio input
  - Real-time GPS coordinates
  - TTS-generated responses

4. HOW WE USE YOUR DATA

We use your data to:
• Authenticate and maintain your account
• Display location, weather, and AQI information
• Process voice commands and generate responses
• Enable conversation history review
• Personalize your experience
• Maintain application functionality

We DO NOT:
• Sell or share your data with third parties
• Use your data for marketing or advertising
• Store voice data on servers
• Build profiles for behavioral targeting

5. LOCATION & GPS DATA

✓ Permission Required: Yes (you must explicitly enable GPS)
✓ Real-Time Only: GPS data is fetched in real-time and not stored
✓ User Control: Disable GPS anytime in device Settings
✓ No History: We do not maintain location history or tracking

6. VOICE & AUDIO PROCESSING

Voice Input:
• Processed locally on your device
• NOT recorded or stored on servers
• Converted to text and discarded

Voice Recordings (Voice Studio):
• Stored locally only
• Completely under your control
• Can be deleted anytime

7. THIRD-PARTY SERVICES

Google Authentication:
• Managed by Google LLC via Supabase
• Review Google's Privacy Policy for their data practices

Location Services:
• Uses OpenStreetMap's Nominatim for location reverse geocoding

Weather & AQI Data:
• Fetched from public APIs in real-time
• Not stored on our servers

AI Response Generation:
• Your text queries may be sent to third-party AI providers
• Third parties may log and process your queries
• Review third-party provider privacy policies

8. WORLD RADIO & WORLD TV FEATURES - THIRD-PARTY SERVICES

These are OPTIONAL entertainment features located in the games/entertainment section.

What They Do:
• Provide access to third-party radio and TV streaming services
• Allow you to browse and stream content from around the world

IMPORTANT DISCLAIMER:
• Controlled by third-party service providers
• We DO NOT collect data from these features
• We DO NOT receive revenue from third-party advertisements
• We DO NOT own the radio stations, TV channels, or content
• We DO NOT control what third parties collect

Third-Party Providers May Collect:
• Your IP address and device information
• Viewing/listening history
• Duration of content consumption
• Cookies and tracking technologies
• Other data as defined in their privacy policies

Your Responsibility:
• Review third-party provider's privacy policy before use
• Understand you are using third-party services, not our service
• Third parties operate under their own terms and policies

9. ADVERTISEMENTS & EXTERNAL CONTENT

In-App Advertisements:
• May be served by Google AdMob or similar networks
• Ad networks may collect device identifier and track impressions
• You can manage ad personalization in Android Settings

External Links & Content:
• The Application contains links to third-party websites
• Third-party sites have their own privacy policies
• We are not responsible for third-party data practices
• Use third-party services at your own discretion

10. YOUR PRIVACY RIGHTS & DATA CONTROL

You Have Full Control:
✓ View profile information in Profile screen
✓ Delete chat history in History screen
✓ Clear all app data in Settings screen
✓ Disable GPS in device Settings
✓ Manage privacy preferences in Privacy Settings
✓ Sign out and reset the application anytime

Right to Access:
• Request information about what data we store

Right to Deletion:
• Delete all personal information from your device anytime
• Request deletion of your account data from our servers

Right to Data Portability:
• Your chat history remains your data
• You can back up Application data using Android tools

Right to Withdraw Consent:
• Uninstall the Application
• Disable permissions in device Settings

11. PERMISSIONS & JUSTIFICATIONS

Location (GPS):
• Required for location, weather, and AQI features
• Can be disabled in Android Settings

Microphone:
• Required for voice commands and Voice Studio recording
• Can be disabled in Android Settings

Internet:
• Required for weather, authentication, and AI services
• Core features require internet access

File Storage:
• Required to save chat history, settings, recordings
• Can be managed in Android storage settings

Audio Output:
• Required to play voice responses and notifications
• Can be managed via device volume settings

12. DATA SECURITY

Local Device Security:
• Protected by your device's built-in security
• Encrypted using GetStorage library
• Protected by your device's PIN/pattern/biometric authentication

Server-Side Security:
• Database encryption at rest
• HTTPS/TLS 1.2+ encryption in transit
• Restricted access controls
• Supabase security infrastructure

13. CHILDREN'S PRIVACY

Age Restriction: 13+ (or as required by local law)

For Users 13-18:
• Parents should be aware of our data practices
• Parents can manage permissions in Android Settings
• Parents can request deletion of child's data

We DO NOT:
• Collect personal information from children under 13
• Serve targeted ads to users under 18
• Use children's data for behavioral targeting

14. CONTACT INFORMATION

For privacy questions, requests, or concerns:

Developer: Sourav Kumar
Location: Jamshedpur, Jharkhand, India
Expertise: Flutter Development, AI Integration

Contact Methods:
• View About screen in Application for support options
• Submit data subject requests (access, deletion, portability)
• Report security issues or child safety concerns

15. DATA RETENTION

Authentication Data:
• Retained while account is active
• Deleted upon request

Chat History:
• Retained until you manually delete
• Automatically deleted when app is uninstalled

Voice Recordings:
• Retained until you manually delete
• Automatically deleted when app is uninstalled

Settings & Preferences:
• Retained until you reset
• Automatically deleted when app is uninstalled

16. POLICY UPDATES

We may update this Privacy Policy to:
• Comply with new legal requirements
• Reflect changes in our data practices
• Improve clarity and transparency

When Changes Occur:
• We update the "Last Updated" date
• We display a notice in the Application
• Continued use means you accept the changes

17. COMPLIANCE & STANDARDS

This Privacy Policy complies with:
• Google Play Store policies
• Android security guidelines
• GDPR (where applicable)
• COPPA (protection for children under 13)
• Industry best practices

18. ACKNOWLEDGMENT

By using CTJ Voice Chat v1.0, you:
✓ Have read and understand this Privacy Policy
✓ Consent to our data practices
✓ Acknowledge risks of third-party services
✓ Accept responsibility for third-party privacy policies
✓ Understand we are not liable for third-party data practices

Last Updated: June 2026
Version: 1.0 for CTJ Voice Chat v1.0

Your privacy is important to us. Please contact us if you have questions or concerns about this policy or our data practices.
''',
                    style: TextStyle(
                      fontSize: context.r.sp(13),
                      color: const Color(0xFF5A3E54),
                      height: 1.6,
                    ),
                  ),
                ),
              ),
              const RSizedBox(h: 24),
              Semantics(
                label: 'I understand',
                button: true,
                child: GestureDetector(
                  onTap: () => Get.back(),
                  child: Container(
                  width: double.infinity,
                  padding: context.r.symmetric(v: 14, h: 0),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFFFB2EE),
                        Color(0xFFFF69B4),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(context.r.scale(12)),
                  ),
                  child: Center(
                    child: Text(
                      'I Understand',
                      style: TextStyle(
                        fontSize: context.r.sp(16),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
