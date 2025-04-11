import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  final AuthService authService;

  const HomeScreen({super.key, required this.authService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  String _errorMessage = '';
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      final userData = await widget.authService.fetchUserAccount();
      
      setState(() {
        _userData = userData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await widget.authService.logout();
              if (context.mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              }
            },
            tooltip: l10n.logoutButton,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _loadUserData,
                        child: Text(l10n.retryButton),
                      ),
                    ],
                  ),
                )
              : _buildUserProfile(),
    );
  }

  Widget _buildUserProfile() {
    if (_userData == null) {
      return const Center(child: Text('No user data available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(_userData!['avatar']),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _userData!['display_name'] ?? _userData!['username'],
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          if (_userData!['display_name'] != null) 
            Center(
              child: Text(
                '@${_userData!['username']}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey,
                ),
              ),
            ),
          const SizedBox(height: 20),
          if (_userData!['note'] != null && _userData!['note'].isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bio',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(_userData!['note']),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatColumn('Following', _userData!['following_count'].toString()),
                  _buildStatColumn('Followers', _userData!['followers_count'].toString()),
                  _buildStatColumn('Posts', _userData!['statuses_count'].toString()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String count) {
    return Column(
      children: [
        Text(
          count,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
} 