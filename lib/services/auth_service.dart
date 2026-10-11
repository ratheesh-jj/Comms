import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsign;
import 'package:logging/logging.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';

class AuthService with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final gsign.GoogleSignIn _googleSignIn = gsign.GoogleSignIn.instance;
  final Logger _log = Logger('AuthService');

  // Stream to listen to auth state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize(
        serverClientId: const String.fromEnvironment(
          'GOOGLE_SERVER_CLIENT_ID',
          defaultValue:
              '375667342199-368m1nuujbvetjvo8n1btt5258cmvrou.apps.googleusercontent.com',
        ), // Web Client ID from Google Cloud (Used for Supabase)
        clientId: const String.fromEnvironment(
          'GOOGLE_IOS_CLIENT_ID',
          defaultValue: 'TODO_ADD_IOS_CLIENT_ID',
        ), // iOS Client ID from Google Cloud
      );

      // Trigger the authentication flow
      final gsign.GoogleSignInAccount googleUser = await _googleSignIn
          .authenticate();

      final gsign.GoogleSignInAuthentication googleAuth =
          googleUser.authentication;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      // Try to get an access token
      final authz = await googleUser.authorizationClient.authorizationForScopes(
        ['email', 'https://www.googleapis.com/auth/userinfo.profile'],
      );
      final accessToken = authz?.accessToken;

      final AuthResponse response = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      final user = response.user;
      if (user != null) {
        final avatarUrl = user.userMetadata?['avatar_url'];
        if (avatarUrl != null) {
          await _supabase.from('users').update({
            'avatar_url': avatarUrl,
          }).eq('id', user.id);
          _log.info('Synced avatar_url for user ${user.id}');
        }
      }

      return user;
    } catch (e) {
      _log.severe("Error signing in with Google: $e");
      return null;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.initialize();
      await _googleSignIn.signOut();
    } catch (_) {}
    await _supabase.auth.signOut();
  }

  // Update profile image
  Future<String?> updateProfileImage(File imageFile) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final fileExt = path.extension(imageFile.path);
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath = '${user.id}/$fileName';

      // Upload to storage
      await _supabase.storage.from('avatars').upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(upsert: true),
          );

      // Get public URL
      final String imageUrl =
          _supabase.storage.from('avatars').getPublicUrl(filePath);

      // Update users table
      await _supabase.from('users').update({
        'avatar_url': imageUrl,
      }).eq('id', user.id);

      _log.info('Updated profile image for user ${user.id}: $imageUrl');
      notifyListeners();
      return imageUrl;
    } catch (e) {
      _log.severe("Error updating profile image: $e");
      return null;
    }
  }

  // Reset profile image to default (Google or generic icon)
  Future<bool> resetProfileImage() async {
    final user = currentUser;
    if (user == null) return false;

    try {
      // Clear avatar_url in users table
      await _supabase.from('users').update({
        'avatar_url': null,
      }).eq('id', user.id);

      // Also clear any custom avatar_url from Auth metadata
      // This allows fallback to the original provider's picture if it exists
      await _supabase.auth.updateUser(
        UserAttributes(data: {'avatar_url': null}),
      );
      
      _log.info('Reset profile image to default for user ${user.id}');
      notifyListeners();
      return true;
    } catch (e) {
      _log.severe("Error resetting profile image: $e");
      return false;
    }
  }
}
