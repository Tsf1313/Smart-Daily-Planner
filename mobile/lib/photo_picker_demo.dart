import 'dart:io';

import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  runApp(const MaterialApp(home: PhotoPickerDemo()));
}

class PhotoPickerDemo extends StatefulWidget {
  const PhotoPickerDemo({super.key});

  @override
  State<PhotoPickerDemo> createState() => _PhotoPickerDemoState();
}

class _PhotoPickerDemoState extends State<PhotoPickerDemo> {
  final ImagePicker _picker = ImagePicker();
  XFile? _photo;
  bool _isPicking = false;

  Future<void> _pickPhoto(ImageSource source) async {
    setState(() => _isPicking = true);

    try {
      final photo = await _picker.pickImage(source: source);
      if (!mounted || photo == null) return;

      setState(() => _photo = photo);
    } on PlatformException {
      if (!mounted) return;

      final message = source == ImageSource.camera
          ? 'Could not open the camera. Try choosing from Gallery.'
          : 'Could not open the gallery.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final photo = _photo;

    return Scaffold(
      appBar: AppBar(title: const Text('Photo Picker Demo')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          FilledButton(
            onPressed: _isPicking ? null : () => _pickPhoto(ImageSource.camera),
            child: const Text('Take Photo'),
          ),
          OutlinedButton(
            onPressed: _isPicking ? null : () => _pickPhoto(ImageSource.gallery),
            child: const Text('Choose from Gallery'),
          ),
          const SizedBox(height: 16),
          if (photo == null)
            const Center(child: Text('No photo selected'))
          else ...[
            Image.file(
              File(photo.path),
              height: 240,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Text('Could not display this photo.');
              },
            ),
            TextButton(
              onPressed: () => setState(() => _photo = null),
              child: const Text('Remove Photo'),
            ),
          ],
        ],
      ),
    );
  }
}