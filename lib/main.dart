import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'services/auth_service.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';

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

class MyApp extends StatefulWidget {
  final AuthService authService;
  
  const MyApp({Key? key, required this.authService}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  
  @override
  void initState() {
    super.initState();
    _checkAuthentication();
    
    // Listen for authentication changes from redirect
    redirectStream.listen((url) async {
      final uri = Uri.parse(url);
      if (uri.scheme == 'saman' && uri.host == 'oauth') {
        await Future.delayed(const Duration(seconds: 1));
        _checkAuthentication();
      }
    });
  }
  
  Future<void> _checkAuthentication() async {
    print('Checking authentication status...');
    final isAuth = await widget.authService.isAuthenticated();
    print('Authentication check result: $isAuth');
    setState(() {
      _isAuthenticated = isAuth;
      _isLoading = false;
    });
  }

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
      home: _isLoading
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _isAuthenticated
              ? HomeScreen(authService: widget.authService)
              : LoginScreen(authService: widget.authService),
      routes: {
        '/login': (context) => LoginScreen(authService: widget.authService),
        '/home': (context) => HomeScreen(authService: widget.authService),
      },
    );
  }
}
