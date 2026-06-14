# Privacy Policy for CTJ Voice Chat v1.0

**Developer:** Sourav Kumar  
**Location:** Jamshedpur, India  
**Expertise:** Flutter Mobile Application Development  
**Last Updated:** May 2026  
**Version:** 1.0  
**Application:** CTJ Voice Chat v1.0

---

## 1. Introduction

Welcome to CTJ Voice Chat v1.0 ("Application," "we," "our," or "us")! We respect your privacy and are committed to protecting your personal data. This privacy policy will inform you about how we collect, use, store, and protect your information when you use our mobile application.

We understand that privacy is paramount. Our application is designed with a privacy-first approach where most of your data remains on your device and is never transmitted to our servers.

---

## 2. Information We Collect

### 2.1 User Authentication & Profile Data

When you sign in via **Google Authentication**, we collect and store:

- **Name** - from your Google account
- **Email address** - from your Google account
- **User ID** - provided by the authentication provider
- **Profile image URL** - from your Google account (if available)

**Important:** We collect ONLY these four fields. No other personal information (age, gender, spiritual preferences, phone number, etc.) is automatically extracted or collected during sign-in.

### 2.2 Location & Weather Data

To provide location-based features, we require GPS permission and collect:

- **GPS coordinates** - latitude and longitude of your current location
- **Location name** - reverse-geocoded from GPS coordinates using OpenStreetMap's Nominatim service
- **Current temperature** - at your location from weather APIs
- **Air Quality Index (AQI)** - air quality data for your location

**Key Point:** GPS must be explicitly enabled by you through your device's location services. These features cannot work without your permission.

### 2.3 Voice & Audio Data

- **Voice input** - processed locally on your device using Speech-to-Text (STT) technology
- **Voice input is NOT recorded or stored** on our servers
- **Voice input is NOT transmitted** to external voice processing services for permanent storage
- **Voice recordings in Voice Studio** - created by you and stored locally on your device only
- **TTS-generated audio responses** - temporarily generated and not saved

---

### 2.4 Chat History & Conversation Data

- **All chat messages** - stored exclusively on your local device
- **Conversation history** - NOT uploaded to our servers
- **User queries and AI responses** - remain on your device
- **Deletion capability** - you can view, delete, or clear all chat history through the History screen anytime

### 2.5 Application Settings & Preferences

- Theme mode preferences (light/dark)
- Language selection
- Wallpaper preferences
- Privacy settings selections
- Alarm and reminder configurations
- Custom app settings

All settings are stored securely on your local device using encrypted local storage (GetStorage).

---

## 3. How We Use Your Data

### 3.1 Profile Data Usage

- To authenticate and maintain your secure session within the application
- To display your name and email on your profile screen
- To personalize your experience with the AI voice assistant
- To retrieve your profile picture from Google for display

### 3.2 Location & Weather Data Usage

- To display your current location on the home screen and top panel
- To show real-time weather information for your area
- To provide Air Quality Index (AQI) information for your health awareness
- Location data is fetched in real-time and used only for display purposes
- NO tracking or location history is maintained

### 3.3 Voice & Audio Data Usage

- To process your voice commands and provide AI-generated responses
- To improve speech recognition accuracy for your personal device
- Voice data is processed locally and never transmitted to external servers for permanent storage
- Audio responses are generated temporarily and discarded after playback

### 3.4 Chat History Usage

- To enable you to review past conversations
- To provide conversation continuity across app sessions
- For your personal reference and record-keeping
- To help the AI understand context in ongoing conversations (only on your device)

### 3.5 General Usage Principles

- We do **NOT** sell, trade, or rent your personal information to third parties
- We do **NOT** use your data for marketing or advertising purposes
- We do **NOT** share your data with external analytics services
- We do **NOT** use your data for any purpose beyond what is explicitly stated in this policy

---

## 4. What Data Is Stored Where

### 4.1 Data Stored Locally on Your Device (All User Data)

- ✓ Chat history and conversation logs
- ✓ Voice recordings created in Voice Studio
- ✓ Alarms and reminders you create
- ✓ User profile information (name, email from Google authentication)
- ✓ Application preferences and settings
- ✓ Wallpaper selections and configurations
- ✓ Privacy settings choices

### 4.2 Data Stored on Our Servers (Supabase - Minimal Infrastructure Data)

- ✓ API Keys and configuration secrets (for app functionality and preventing API breakage)
- ✓ Wallpaper catalog metadata (list of available wallpapers)
- ✓ Authentication credentials (managed securely by Supabase)

We maintain strict access controls, encryption, and security protocols for all server-side data.

### 4.3 Data That Is NEVER Stored

- ✗ Voice input/STT audio files
- ✗ Real-time location coordinates
- ✗ GPS data history
- ✗ TTS-generated audio responses
- ✗ Temporary processing data

---

## 5. Third-Party Services & Data Sharing

### 5.1 Google Authentication

- We use **Google Sign-In via Supabase OAuth** for secure user authentication
- Your Google account data (name, email, profile picture) is retrieved only during sign-in
- We do NOT access your Google Drive, Gmail, Calendar, or any other Google services
- For information about how Google handles your data, refer to [Google's Privacy Policy](https://policies.google.com/privacy)

### 5.2 Location Services

- Location data is obtained through your device's **native GPS** (geolocator package)
- We process this data locally on your device
- We use **OpenStreetMap's Nominatim service** for reverse geocoding (converting GPS coordinates to location names)
- Location data is NOT stored on our servers or your cloud accounts

### 5.3 Weather & Air Quality Data

- Weather and AQI data is fetched from **public weather APIs** in real-time
- This data is displayed to you immediately
- Data is **NOT stored** on our servers or your device
- Each time you open the app, fresh data is fetched

### 5.4 Voice Processing

- Voice input is processed using **on-device Speech-to-Text technology**
- We do **NOT use external voice processing services** that store audio
- Voice data remains on your device only

### 5.5 Backend Infrastructure
- **Supabase** - used for authentication and storing API keys/configuration secrets
- **PostgreSQL Database** - encrypted and securely managed by Supabase
- All data transmission uses **HTTPS encryption**

---

## 6. Your Privacy Rights & Data Control

You have full and complete control over your data:

- **View Your Profile** - Access all stored profile information in the Profile screen
- **Delete Chat History** - Remove all conversations and chat logs in the History screen
- **Clear All Data** - Reset the entire app and all stored data in the Settings screen
- **Disable Location** - Disable GPS services in your device's Settings anytime
- **Manage Privacy Preferences** - Adjust privacy settings in the Privacy Settings screen
- **Sign Out** - Sign out from your account and delete profile data by logging out
- **Revoke Permissions** - Grant or revoke microphone, location, and file access permissions through device Settings
- **Delete App Data** - Upon app uninstall, all local data is automatically removed from your device

You can exercise these rights at any time without contacting us.

---

## 7. Data Security & Protection

### Local Device Security
- All personal data stored on your local device is protected by your device's built-in security measures
- Data is stored using **encrypted local storage** (GetStorage with encryption)
- Your device's lock screen and biometric security also protect this data

### Server-Side Security
- Server-side data (API keys, wallpaper metadata) is stored in a **Supabase-managed PostgreSQL database**
- Supabase implements **industry-standard encryption** and security protocols
- All data transmitted to our servers uses **HTTPS encryption** (TLS 1.2+)
- We do NOT transmit your chat history or personal conversations over unencrypted connections

### General Security Practices
- We do NOT store passwords (you authenticate via Google)
- We do NOT store sensitive personal information on servers
- We implement access controls to prevent unauthorized data access
- We regularly review our security practices

---

## 8. Children's Privacy

Our application may be used by children with parental consent and supervision.

### For Children
- We do NOT knowingly collect additional personal information from children beyond what is necessary for app functionality
- Parents/guardians should monitor their children's usage

### For Parents/Guardians
- You can control **location permissions** through your device's Settings
- You can control **microphone access** through your device's Settings
- You can control **privacy settings** within the app
- You can reset all app data anytime
- We recommend parental supervision for children under 13

---

## 9. Permissions Required by the Application

The application requests the following permissions:

| Permission | Purpose |
|-----------|---------|
| **GPS Location** | Display current location, temperature, and AQI information |
| **Microphone** | Process voice input and record custom voice samples in Voice Studio |
| **File Storage** | Save chat history, preferences, and custom recordings locally |
| **Audio** | Play audio responses, sound effects, and TTS output |
| **Internet** | Fetch weather data, authenticate with Google, and download wallpapers |

**You can grant or revoke these permissions at any time in your device's Settings.**

---

## 10. Changes to This Privacy Policy

We may update this Privacy Policy periodically to:
- Reflect changes in our practices
- Comply with legal or regulatory requirements
- Improve clarity and transparency
- Address new features or services

### How We Notify You
- We will update the "Last Updated" date at the top of this policy
- For significant changes, we will display a notice in the application on your next login
- We will maintain transparency about what has changed

### Your Continued Use
Your continued use of the application after changes to the Privacy Policy means you accept the updated policy.

---

## 11. Data Retention

### Profile Data
- Retained as long as your account is active
- Deleted when you sign out and reset the app

### Chat History
- Retained indefinitely until you manually delete it
- You have complete control over deletion through the History screen

### Local Settings & Preferences
- Retained until you manually reset the application
- Preserved across app updates (unless you clear app data)

### Voice Recordings
- Retained on your device until you delete them
- Stored only locally, never on our servers

### Server-Side Data
- API keys retained to maintain app functionality
- Wallpaper metadata retained to serve wallpaper catalog
- Stored with encryption and access controls

### Upon App Uninstall
- All local data is automatically removed from your device
- Server-side configuration data remains (cannot be linked to you personally)

---

## 12. Compliance & Standards

This Privacy Policy is designed to comply with:
- Standard mobile application privacy best practices
- Google Play Store Privacy Policy requirements
- Data protection principles (collection limitation, use limitation, storage limitation)
- Transparency and user consent principles

We are committed to:
- Protecting your privacy
- Being transparent about data practices
- Ensuring you have a positive and secure experience with CTJ Voice Chat v1.0

---

## 13. Contact Information

If you have any questions, concerns, or requests regarding this Privacy Policy or our privacy practices, please contact:

**Developer Information:**
- **Name:** Sourav Kumar
- **Location:** Jamshedpur, India
- **Expertise:** Flutter Mobile Application Development for Android & iOS
- **Availability:** Open to new opportunities and collaboration

**Contact Methods:**
Please refer to the **About screen** within the application for:
- Support email and contact options
- Social media links
- Additional developer information

---

## 14. Summary of Key Privacy Points

### What We Protect
✓ Your chat history is stored locally, never on our servers  
✓ Your voice input is not recorded or stored  
✓ Your location is not tracked or logged  
✓ Your data is not sold to third parties  
✓ Your data is not used for advertising or marketing  

### What You Control
✓ You can delete all your data anytime  
✓ You can disable GPS permission anytime  
✓ You can disable microphone permission anytime  
✓ You can clear chat history anytime  
✓ You can sign out and reset the app anytime  

### What We Store on Servers
✓ API keys and configuration (for app functionality)  
✓ Wallpaper catalog (for your customization options)  
✓ Everything encrypted with industry standards  

---

**Effective Date:** May 2026  
**Version:** 1.0 for CTJ Voice Chat v1.0  
**Status:** Active and Current

---

*This Privacy Policy is provided in English. If there are any discrepancies between translated versions and the English version, the English version shall prevail.*

*By using CTJ Voice Chat v1.0, you acknowledge that you have read, understood, and agree to this Privacy Policy.*
