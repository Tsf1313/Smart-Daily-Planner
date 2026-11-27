import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../data/repositories/entry_attachments_api.dart';

class TaskPhotoPreview extends StatefulWidget {
  const TaskPhotoPreview({
    super.key,
    required this.photoId,
    required this.api,
    this.height = 200,
    this.width = double.infinity,
  });

  final String photoId;
  final EntryAttachmentsApi api;
  final double height;
  final double width;

  @override
  State<TaskPhotoPreview> createState() => _TaskPhotoPreviewState();
}

class _TaskPhotoPreviewState extends State<TaskPhotoPreview> {
  late final Future<Uint8List> _photo = widget.api.readPhoto(widget.photoId);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: FutureBuilder(
        future: _photo,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                semanticLabel: 'Photo unavailable',
              ),
            );
          }
          final bytes = snapshot.data;
          if (bytes == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(bytes, fit: BoxFit.cover),
          );
        },
      ),
    );
  }
}
