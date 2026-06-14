import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String supabaseUrl = 'https://befcerlzbcauvxkssiwp.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJlZmNlcmx6YmNhdXZ4a3NzaXdwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3OTE2NDAsImV4cCI6MjA5NTM2NzY0MH0.8JkgFSiwYIv3TGF67FgLOaeSJu-Wn8ft_OpISHaECkY';

  late final SupabaseClient client;

  Future<SupabaseService> init() async {
    try {
      // Add a timeout to prevent the entire app from hanging on white screen
      // if the connection to Supabase is slow or blocked.
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      ).timeout(const Duration(seconds: 7));

      client = Supabase.instance.client;
      debugPrint('✅ [SupabaseService] Initialized');
    } catch (e) {
      debugPrint('❌ [SupabaseService] Initialization warning: $e');
      // We don't rethrow here to allow the app to boot in "offline" or "recovery" mode
    }
    return this;
  }

  /// Waits for the Supabase session to be restored from local storage.
  /// This prevents the app from firing API requests before the user is fully recognized.
  Future<void> restoreSession() async {
    try {
      // Check if session exists immediately
      if (client.auth.currentSession != null) {
        debugPrint('✅ [SupabaseService] Session found immediately');
        return;
      }

      debugPrint('⏳ [SupabaseService] Waiting for session restoration...');

      // Wait for auth to settle (max 3 seconds)
      final completer = Completer<void>();
      final subscription = client.auth.onAuthStateChange.listen((data) {
        if (data.session != null) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      // Timeout safety: if no session found in 3s, assume guest or need re-login
      await completer.future.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⚠️ [SupabaseService] Session restoration timed out');
          if (!completer.isCompleted) completer.complete();
        },
      );

      await subscription.cancel();
    } catch (e) {
      debugPrint('❌ [SupabaseService] restoreSession error: $e');
    }
  }

  /// Initiates Google Sign-In using Supabase's native OAuth flow.
  /// This is the most reliable method for production/release builds as it
  /// avoids package conflicts and constructor errors.
  Future<void> signInWithGoogle() async {
    try {
      // This will open the secure system browser for Google login.
      // Once finished, Supabase will handle the session automatically.
      await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.voiceassistant://login-callback',
      );
    } catch (e) {
      debugPrint('❌ [SupabaseService] Google Sign-In failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await client.auth.signOut();
  }

  User? get currentUser => client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Secret Fetching Helpers
  Future<Map<String, dynamic>?> fetchSecrets(String id) async {
    final response = await client
        .from('app_secrets')
        .select('secret_value')
        .eq('id', id)
        .maybeSingle();
    return response?['secret_value'] as Map<String, dynamic>?;
  }

  Future<List<dynamic>?> fetchSecretList(String id) async {
    final response = await client
        .from('app_secrets')
        .select('secret_value')
        .eq('id', id)
        .maybeSingle();
    return response?['secret_value'] as List<dynamic>?;
  }

  Future<String?> fetchSecretString(String id) async {
    final response = await client
        .from('app_secrets')
        .select('secret_value')
        .eq('id', id)
        .maybeSingle();
    return response?['secret_value'] as String?;
  }
}
