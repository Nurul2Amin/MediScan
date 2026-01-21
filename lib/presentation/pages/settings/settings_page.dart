import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';
import 'package:prescription_scanner/presentation/providers/settings_provider.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fullNameController;
  late TextEditingController _phoneController;
  
  // Recommendation preferences
  double _defaultRadiusM = 5000;
  String _sortMode = 'balanced';
  bool _requireFullMatch = false;
  int _maxResults = 20;
  
  // Owner-only preferences
  int _lowStockThreshold = 10;
  bool _showLowStockOnly = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Initialize controllers from current profile
    final profile = ref.read(userProfileProvider).value;
    _fullNameController = TextEditingController(text: profile?.fullName ?? '');
    _phoneController = TextEditingController(text: profile?.phone ?? '');
    
    if (profile != null) {
      _defaultRadiusM = profile.defaultRadiusM.toDouble();
      _sortMode = profile.sortMode;
      _requireFullMatch = profile.requireFullMatch;
      _maxResults = profile.maxResults;
      _lowStockThreshold = profile.lowStockThreshold;
      _showLowStockOnly = profile.showLowStockOnly;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final profile = ref.read(userProfileProvider).value;
      if (profile == null) {
        throw Exception('Profile not found');
      }

      // Build preferences map
      final preferences = <String, dynamic>{};

      // Add recommendation preferences only for customers
      if (!profile.isOwner) {
        preferences['default_radius_m'] = _defaultRadiusM.toInt();
        preferences['sort_mode'] = _sortMode;
        preferences['require_full_match'] = _requireFullMatch;
        preferences['max_results'] = _maxResults;
      }

      // Add owner-only preferences if user is owner
      if (profile.isOwner) {
        preferences['low_stock_threshold'] = _lowStockThreshold;
        preferences['show_low_stock_only'] = _showLowStockOnly;
      }

      await ref.read(settingsProvider.notifier).updateProfile(
        fullName: _fullNameController.text,
        phone: _phoneController.text,
        preferences: preferences,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(userProfileProvider);
    final user = ref.watch(userProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Profile Section
                  _buildSection(
                    title: 'Profile Information',
                    children: [
                      TextFormField(
                        controller: _fullNameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          prefixIcon: Icon(Icons.person),
                        ),
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Read-only email
                      TextFormField(
                        initialValue: user?.email ?? '',
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                        ),
                        enabled: false,
                      ),
                      const SizedBox(height: 16),
                      // Read-only role
                      TextFormField(
                        initialValue: profile.role == 'pharmacy_owner' 
                            ? 'Pharmacy Owner' 
                            : 'Customer',
                        decoration: const InputDecoration(
                          labelText: 'Account Type',
                          prefixIcon: Icon(Icons.account_circle),
                        ),
                        enabled: false,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Recommendation Preferences (Customer Only)
                  if (!profile.isOwner) ...[
                    _buildSection(
                      title: 'Recommendation Preferences',
                      children: [
                        Text('Default Search Radius: ${_defaultRadiusM.toInt()}m'),
                        Slider(
                          value: _defaultRadiusM,
                          min: 1000,
                          max: 20000,
                          divisions: 19,
                          label: '${_defaultRadiusM.toInt()}m',
                          onChanged: (value) {
                            setState(() => _defaultRadiusM = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('Sort Mode'),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'balanced', label: Text('Balanced')),
                            ButtonSegment(value: 'nearest', label: Text('Nearest')),
                            ButtonSegment(value: 'cheapest', label: Text('Cheapest')),
                            ButtonSegment(value: 'most_matched', label: Text('Most Matched')),
                          ],
                          selected: {_sortMode},
                          onSelectionChanged: (Set<String> newSelection) {
                            setState(() => _sortMode = newSelection.first);
                          },
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Require Full Match'),
                          subtitle: const Text('Only show pharmacies with all cart items'),
                          value: _requireFullMatch,
                          onChanged: (value) {
                            setState(() => _requireFullMatch = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Text('Max Results: '),
                            const Spacer(),
                            Text('$_maxResults'),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _maxResults.toDouble(),
                                min: 5,
                                max: 50,
                                divisions: 9,
                                label: '$_maxResults',
                                onChanged: (value) {
                                  setState(() => _maxResults = value.toInt());
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Owner-only preferences
                  if (profile.isOwner) ...[
                    const SizedBox(height: 24),
                    _buildSection(
                      title: 'Inventory Preferences (Owner Only)',
                      children: [
                        Row(
                          children: [
                            const Text('Low Stock Threshold: '),
                            const Spacer(),
                            Text('$_lowStockThreshold'),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Slider(
                                value: _lowStockThreshold.toDouble(),
                                min: 1,
                                max: 100,
                                divisions: 99,
                                label: '$_lowStockThreshold',
                                onChanged: (value) {
                                  setState(() => _lowStockThreshold = value.toInt());
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Show Low Stock Only'),
                          subtitle: const Text('Filter inventory to show only low stock items'),
                          value: _showLowStockOnly,
                          onChanged: (value) {
                            setState(() => _showLowStockOnly = value);
                          },
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 32),
                  
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    ElevatedButton(
                      onPressed: _saveSettings,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save Settings'),
                    ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
