import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/auth_service.dart';
import 'screens/login/login_screen.dart';

// StreamController to handle OAuth redirects
final StreamController<String> _redirectStreamController = StreamController<String>.broadcast();
Stream<String> get redirectStream => _redirectStreamController.stream;

// Function that can be called from native code to handle the OAuth redirect
void handleAuthRedirect(String url) {
  print('Received redirect URL: $url');
  _redirectStreamController.add(url);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Create an instance of AuthService to share with the app
  final authService = AuthService();
  
  // Setup method channel to receive URL scheme redirects
  const MethodChannel channel = MethodChannel('app.mastodon/url_handler');
  channel.setMethodCallHandler((call) async {
    if (call.method == 'handleUrl') {
      final String url = call.arguments as String;
      handleAuthRedirect(url);
    }
    return null;
  });
  
  // Listen for redirects and handle them
  redirectStream.listen((url) {
    final uri = Uri.parse(url);
    if (uri.scheme == 'saman' && uri.host == 'oauth') {
      final code = uri.queryParameters['code'];
      if (code != null) {
        print('Received OAuth code: $code');
        // Complete the OAuth flow with the code
        authService.handleAuthorizationCode(code);
      }
    }
  });
  
  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  final AuthService authService;
  
  const MyApp({Key? key, required this.authService}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Saman',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'), // English
        Locale('pl'), // Polish
        Locale('is'), // Icelandic
      ],
      home: LoginScreen(authService: authService),
    );
  }
}
