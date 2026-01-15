import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prescription_scanner/core/helpers/image_picker_helper.dart';
import 'package:prescription_scanner/core/helpers/permission_helper.dart';
import 'package:prescription_scanner/presentation/providers/medicine_provider.dart';
import 'package:prescription_scanner/presentation/pages/results/results_page.dart';

class ScanPage extends ConsumerStatefulWidget {
  const ScanPage({super.key});

  @override
  ConsumerState<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends ConsumerState<ScanPage> {
  String? _imagePath;

  Future<void> _pickImage(bool fromCamera) async {
    if (fromCamera) {
      final hasPermission = await PermissionHelper.requestCameraPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission denied')),
          );
        }
        return;
      }
    }

    final path = fromCamera
        ? await ImagePickerHelper.pickImageFromCamera()
        : await ImagePickerHelper.pickImageFromGallery();

    if (path != null) {
      setState(() {
        _imagePath = path;
      });
    }
  }

  Future<void> _processImage() async {
    if (_imagePath == null) return;

    // Trigger state processing
    await ref.read(medicineStateProvider.notifier).scanAndProcessPrescription(_imagePath!);
    
    // Navigate to results if mounted
    if (mounted) {
       Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => const ResultsPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicineState = ref.watch(medicineStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Scan Prescription')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _imagePath == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text('No image selected'),
                        ],
                      )
                    : Image.file(File(_imagePath!), fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(false),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(true),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _imagePath == null || medicineState.isLoading
                    ? null
                    : _processImage,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                ),
                child: medicineState.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Analyze Prescription'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
