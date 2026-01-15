import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/presentation/providers/auth_provider.dart';
import 'package:prescription_scanner/presentation/providers/owner_provider.dart';
import 'package:prescription_scanner/data/providers.dart';
import 'package:prescription_scanner/core/helpers/permission_helper.dart';
import 'package:geolocator/geolocator.dart';

class PharmacySetupPage extends ConsumerStatefulWidget {
  const PharmacySetupPage({super.key});

  @override
  ConsumerState<PharmacySetupPage> createState() => _PharmacySetupPageState();
}

class _PharmacySetupPageState extends ConsumerState<PharmacySetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  
  // Location State
  double? _latitude;
  double? _longitude;
  bool _isLocating = false;
  
  bool _isLoading = false;

  Future<void> _detectLocation() async {
    setState(() => _isLocating = true);
    try {
      final hasPermission = await PermissionHelper.requestLocationPermission();
      if (!hasPermission) {
        throw 'Location permission denied';
      }

      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location detected successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to detect location: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  Future<void> _createPharmacy() async {
    if (!_formKey.currentState!.validate()) return;
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please detect your location first')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = ref.read(userProvider);
      final supabase = ref.read(supabaseProvider);

      await supabase.from('pharmacies').insert({
        'owner_id': user!.id,
        'name': _nameCtrl.text,
        'address': _addressCtrl.text,
        'contact_number': _contactCtrl.text,
        'latitude': _latitude,
        'longitude': _longitude,
      });

      // Refresh provider
      ref.invalidate(myPharmacyProvider);
      
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Setup Pharmacy')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Pharmacy Name'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(labelText: 'Address'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _contactCtrl,
                  decoration: const InputDecoration(labelText: 'Contact Number'),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                
                // Location Section
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _latitude != null 
                                  ? 'Loc: ${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}' 
                                  : 'Location not set',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (_isLocating)
                          const LinearProgressIndicator()
                        else
                          ElevatedButton.icon(
                            onPressed: _detectLocation,
                            icon: const Icon(Icons.my_location),
                            label: const Text('Auto-Detect Location'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            
                const SizedBox(height: 30),
                
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _createPharmacy,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Create Pharmacy Profile'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
