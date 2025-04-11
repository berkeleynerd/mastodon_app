import 'dart:convert';
import 'dart:io';
// Modified for development: using in-memory storage for development
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String serverUrl = 'https://social.vivaldi.net';
  static const String _tokenKey = 'mastodon_token';
  static const String _clientIdKey = 'client_id';
  static const String _clientSecretKey = 'client_secret';
  // Modified for development: using in-memory storage for development
  // final _storage = const FlutterSecureStorage();
  
  // In-memory storage for development
  final Map<String, String> _devStorage = {};
  
  Future<void> authenticate() async {
    try {
      // First register the application if we haven't already
      final clientId = _devStorage[_clientIdKey];
      final clientSecret = _devStorage[_clientSecretKey];
      
      if (clientId == null || clientSecret == null) {
        await _registerApp();
      }
      
      final storedClientId = _devStorage[_clientIdKey];
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
      // Modified for development: using in-memory storage for development
      // await _storage.write(key: _clientIdKey, value: data['client_id']);
      // await _storage.write(key: _clientSecretKey, value: data['client_secret']);
      _devStorage[_clientIdKey] = data['client_id'];
      _devStorage[_clientSecretKey] = data['client_secret'];
      
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
      final clientId = _devStorage[_clientIdKey];
      final clientSecret = _devStorage[_clientSecretKey];
      
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
      _devStorage[_tokenKey] = data['access_token'];
      print('Successfully obtained access token');
    } catch (e) {
      print('Handle authorization code error: $e');
      rethrow;
    }
  }

  Future<bool> isAuthenticated() async {
    // Modified for development: using in-memory storage for development
    // final token = await _storage.read(key: _tokenKey);
    final token = _devStorage[_tokenKey];
    return token != null;
  }

  Future<void> logout() async {
    // Modified for development: using in-memory storage for development
    // await _storage.delete(key: _tokenKey);
    // await _storage.delete(key: _clientIdKey);
    // await _storage.delete(key: _clientSecretKey);
    _devStorage.remove(_tokenKey);
    _devStorage.remove(_clientIdKey);
    _devStorage.remove(_clientSecretKey);
  }
} 