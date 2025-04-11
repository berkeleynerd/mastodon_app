import 'dart:convert';
import 'dart:io';
// Using SharedPreferences instead of flutter_secure_storage
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String serverUrl = 'https://social.vivaldi.net';
  static const String _tokenKey = 'mastodon_token';
  static const String _clientIdKey = 'client_id';
  static const String _clientSecretKey = 'client_secret';
  
  // Method to get the access token
  Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }
  
  // Method to check if the user is authenticated
  Future<bool> isAuthenticated() async {
    final token = await getAccessToken();
    print('Auth check - token exists: ${token != null}');
    if (token == null) return false;
    
    try {
      // Verify the token is valid by making a request to the API
      print('Verifying token validity...');
      final response = await _authorizedGet('/api/v1/accounts/verify_credentials');
      print('Token verification response: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Token validation error: $e');
      return false;
    }
  }
  
  // Method to fetch the user's account information
  Future<Map<String, dynamic>> fetchUserAccount() async {
    print('Fetching user account...');
    final response = await _authorizedGet('/api/v1/accounts/verify_credentials');
    
    print('User account response: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw 'Failed to fetch account: ${response.body}';
    }
    
    final userData = jsonDecode(response.body);
    print('User data retrieved: ${userData['username']}');
    return userData;
  }
  
  // Helper method for authorized GET requests
  Future<http.Response> _authorizedGet(String path) async {
    final token = await getAccessToken();
    if (token == null) {
      throw 'Not authenticated';
    }
    
    return http.get(
      Uri.parse('$serverUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10), onTimeout: () {
      throw 'Connection timeout. Please check your network connection.';
    });
  }
  
  Future<void> authenticate() async {
    try {
      // First register the application if we haven't already
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString(_clientIdKey);
      final clientSecret = prefs.getString(_clientSecretKey);
      
      if (clientId == null || clientSecret == null) {
        await _registerApp();
      }
      
      final storedClientId = prefs.getString(_clientIdKey);
      if (storedClientId == null) {
        throw 'Failed to register application';
      }

      final authUrl = Uri.parse('$serverUrl/oauth/authorize').replace(
        queryParameters: {
          'client_id': storedClientId,
          'redirect_uri': 'saman://oauth',
          'response_type': 'code',
          'scope': 'read write follow',
        },
      );

      print('Launching URL: $authUrl');
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch authentication URL: $authUrl';
      }
    } catch (e) {
      print('Authentication error: $e');
      rethrow;
    }
  }

  Future<void> _registerApp() async {
    try {
      print('Registering application with $serverUrl');
      final response = await http.post(
        Uri.parse('$serverUrl/api/v1/apps'),
        body: {
          'client_name': 'Saman',
          'redirect_uris': 'saman://oauth',
          'scopes': 'read write follow',
          'website': 'https://github.com/berkeleynerd/mastodon_app'
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw 'Connection timeout. Please check your network connection.';
      });

      print('Register app response: ${response.statusCode} - ${response.body}');
      if (response.statusCode != 200) {
        throw 'Failed to register application: ${response.body}';
      }

      final data = jsonDecode(response.body);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clientIdKey, data['client_id']);
      await prefs.setString(_clientSecretKey, data['client_secret']);
      
      print('Successfully registered app with client ID: ${data['client_id']}');
    } on SocketException catch (e) {
      print('Network error: $e');
      throw 'Network error: Could not connect to the server. Please check your internet connection.';
    } catch (e) {
      print('Register app error: $e');
      rethrow;
    }
  }
  
  // Handle the OAuth authorization code received from the redirect
  Future<void> handleAuthorizationCode(String code) async {
    try {
      print('Exchanging authorization code for token');
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString(_clientIdKey);
      final clientSecret = prefs.getString(_clientSecretKey);
      
      if (clientId == null || clientSecret == null) {
        throw 'Missing client credentials';
      }
      
      final response = await http.post(
        Uri.parse('$serverUrl/oauth/token'),
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': 'saman://oauth',
        },
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw 'Connection timeout. Please check your network connection.';
      });
      
      print('Token response: ${response.statusCode} - ${response.body}');
      if (response.statusCode != 200) {
        throw 'Failed to exchange code for token: ${response.body}';
      }
      
      final data = jsonDecode(response.body);
      // Store the access token
      await prefs.setString(_tokenKey, data['access_token']);
      print('Successfully obtained access token');
    } catch (e) {
      print('Handle authorization code error: $e');
      rethrow;
    }
  }

  Future<void> logout() async {
    print('Logging out and clearing all credentials');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    // Optionally, also clear app credentials if you want to force re-registration
    // await prefs.remove(_clientIdKey);
    // await prefs.remove(_clientSecretKey);
  }
} 