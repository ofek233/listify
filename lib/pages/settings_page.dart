import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../utils/theme_provider.dart';
import '../utils/app_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  
  late TextEditingController _emailController;
  late TextEditingController _usernameController;
  bool _isLoadingProfile = true;
  bool _isDarkMode = false;
  String? _currentEmail;
  String? _currentUsername;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _usernameController = TextEditingController();
    _loadUserProfile();
    _loadThemePreferences();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final user = _authService.currentUser;
    if (user == null) {
      if (mounted) Navigator.pop(context);
      return;
    }

    try {
      final userDoc = await _firestoreService.getUserInfo(user.uid);
      if (mounted) {
        setState(() {
          _currentEmail = user.email ?? '';
          _currentUsername = userDoc?['displayName'] ?? '';
          _emailController.text = _currentEmail ?? '';
          _usernameController.text = _currentUsername ?? '';
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoadingProfile = false);
      }
    }
  }

  Future<void> _loadThemePreferences() async {
    try {
      final user = _authService.currentUser;
      bool? darkModeFromCloud;
      if (user != null) {
        final prefs = await _firestoreService.getUserPreferences(user.uid);
        darkModeFromCloud = prefs?['darkMode'] as bool?;
      }

      final isDarkMode = darkModeFromCloud ?? await AppTheme.getThemeMode();
      if (mounted) {
        setState(() {
          _isDarkMode = isDarkMode;
        });
      }

      if (mounted) {
        final themeProvider = context.read<ThemeProvider>();
        if (themeProvider.isDarkMode != isDarkMode) {
          await themeProvider.setDarkMode(isDarkMode);
        }
      }
    } catch (e) {
      print('Error loading theme preferences: $e');
    }
  }

  Future<void> _updateEmail() async {
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email cannot be empty')),
      );
      return;
    }

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Update email in Firebase Auth using verifyBeforeUpdateEmail
      await user.verifyBeforeUpdateEmail(_emailController.text.trim());
      
      // Update email in Firestore
      await _firestoreService.updateUserEmail(user.uid, _emailController.text.trim());

      if (mounted) {
        setState(() => _currentEmail = _emailController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email updated successfully. Please verify in your email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating email: $e')),
        );
      }
    }
  }

  Future<void> _updateUsername() async {
    if (_usernameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username cannot be empty')),
      );
      return;
    }

    try {
      final user = _authService.currentUser;
      if (user == null) return;

      // Update username/displayName in Firestore
      await _firestoreService.updateUserDisplayName(user.uid, _usernameController.text.trim());

      if (mounted) {
        setState(() => _currentUsername = _usernameController.text.trim());
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Username updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating username: $e')),
        );
      }
    }
  }

  void _showChangePasswordDialog() {
    final passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New Password',
            hintText: 'Enter new password',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (passwordController.text.trim().isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password cannot be empty')),
                  );
                }
                return;
              }

              try {
                final user = _authService.currentUser;
                if (user == null) return;

                await user.updatePassword(passwordController.text.trim());

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password updated successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error updating password: $e')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoadingProfile
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    // Email
                    const Text('Email', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Email address',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _updateEmail,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Update Email'),
                    ),
                    const SizedBox(height: 24),

                    // Username
                    const Text('Username', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: 'Username',
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _updateUsername,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Update Username'),
                    ),
                    const SizedBox(height: 24),

                    // Password
                    const Text('Password', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _showChangePasswordDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.secondary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Change Password'),
                    ),
                    const SizedBox(height: 24),

                    // Theme Customization
                    const Text('Theme', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    
                    // Dark Mode Toggle
                    SwitchListTile(
                      title: const Text('Dark Mode'),
                      value: _isDarkMode,
                      activeThumbColor: Theme.of(context).colorScheme.secondary,
                      onChanged: (bool value) async {
                        try {
                          final themeProvider = context.read<ThemeProvider>();
                          await themeProvider.setDarkMode(value);
                          final user = _authService.currentUser;
                          if (user != null) {
                            await _firestoreService.updateUserPreferences(
                              user.uid,
                              darkMode: value,
                            );
                          }
                          if (mounted) {
                            setState(() {
                              _isDarkMode = value;
                            });
                          }
                          print('Dark mode toggled to: $value');
                        } catch (e) {
                          print('Error toggling dark mode: $e');
                        }
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Secondary Color Selection
                    const Text('Secondary Color', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    Consumer<ThemeProvider>(
                      builder: (context, themeProvider, child) {
                        return SizedBox(
                          height: 50,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: AppTheme.availableColors.length,
                            itemBuilder: (context, index) {
                              final isSelected = themeProvider.selectedColorIndex == index;
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () async {
                                    try {
                                      await themeProvider.setSecondaryColor(index);
                                      print('Color changed to index: $index');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Theme updated')),
                                        );
                                      }
                                    } catch (e) {
                                      print('Error changing color: $e');
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Error changing color')),
                                        );
                                      }
                                    }
                                  },
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: AppTheme.availableColors[index],
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? Border.all(color: Colors.white, width: 3)
                                          : null,
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: AppTheme.availableColors[index]
                                                    .withOpacity(0.5),
                                                blurRadius: 8,
                                                spreadRadius: 2,
                                              )
                                            ]
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 40),

                    // Sign Out Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _showSignOutDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.white, fontSize: 16),
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
