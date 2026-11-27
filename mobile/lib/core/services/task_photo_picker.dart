import 'dart:io';

import 'package:image_picker/image_picker.dart';

const maxTaskPhotoBytes = 5 * 1024 * 1024;

class TaskPhotoException implements Exception {
  const TaskPhotoException(this.message);
  final String message;
}

Future<String> taskPhotoMimeType(XFile file) async {
  final length = await file.length();
  if (length > maxTaskPhotoBytes) {
    throw const TaskPhotoException('Choose a photo of 5 MB or less.');
  }
  if (length < 8) {
    throw const TaskPhotoException('Choose a JPEG or PNG image.');
  }

  final reader = await File(file.path).open();
  try {
    final header = await reader.read(8);
    const png = [137, 80, 78, 71, 13, 10, 26, 10];
    if (header.length == png.length &&
        Iterable<int>.generate(png.length).every((i) => png[i] == header[i])) {
      return 'image/png';
    }
    if (header.length >= 3 &&
        header[0] == 255 && header[1] == 216 && header[2] == 255) {
      return 'image/jpeg';
    }
    throw const TaskPhotoException('Choose a JPEG or PNG image.');
  } finally {
    await reader.close();
  }
}
