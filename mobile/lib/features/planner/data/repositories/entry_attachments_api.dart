import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/services/task_photo_picker.dart';
import '../../../locations/data/models/selected_facility.dart';

class EntryAttachmentException implements Exception {
  const EntryAttachmentException(this.status, this.message);
  final int status;
  final String message;
}

/// Uses the signed-in app's client and token provider. The caller owns the client.
class EntryAttachmentsApi {
  const EntryAttachmentsApi({
    required this.baseUrl,
    required this.client,
    required this.idToken,
  });

  final Uri baseUrl;
  final http.Client client;
  final Future<String?> Function() idToken;

  Uri _uri(String path, [Map<String, String>? query]) =>
      baseUrl.resolve('/api/v1/$path').replace(queryParameters: query);

  Future<Map<String, String>> _headers() async {
    final local = ['localhost', '127.0.0.1', '10.0.2.2'].contains(baseUrl.host);
    if (baseUrl.scheme != 'https' && !(baseUrl.scheme == 'http' && local)) {
      throw const EntryAttachmentException(
        0,
        'Use HTTPS for a hosted planner API.',
      );
    }
    final token = await idToken().timeout(const Duration(seconds: 12));
    if (token == null || token.isEmpty) {
      throw const EntryAttachmentException(401, 'Sign in to continue.');
    }
    return {'Authorization': 'Bearer $token'};
  }

  Future<Map<String, dynamic>> requestJson(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
  }) async {
    final request = http.Request(method, _uri(path, query))
      ..headers.addAll(await _headers())
      ..followRedirects = false;
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _data(await _send(request));
  }

  Future<http.Response> _send(http.BaseRequest request) => client
      .send(request)
      .then(http.Response.fromStream)
      .timeout(const Duration(seconds: 20));

  Future<List<({SelectedFacility facility, double distanceMeters})>> nearby({
    required double latitude,
    required double longitude,
  }) async {
    final data = await requestJson(
      'GET',
      'facilities',
      query: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );
    final items = data['items'] as List<dynamic>;
    return [
      for (final item in items.cast<Map<String, dynamic>>())
        (
          facility: SelectedFacility(
            id: item['facilityId'] as String,
            name: item['name'] as String,
            latitude: (item['latitude'] as num).toDouble(),
            longitude: (item['longitude'] as num).toDouble(),
          ),
          distanceMeters: (item['distanceMeters'] as num).toDouble(),
        ),
    ];
  }

  Future<Uint8List> readPhoto(String id) async {
    final request =
        http.Request('GET', _uri('photos/${Uri.encodeComponent(id)}'))
          ..headers.addAll(await _headers())
          ..followRedirects = false;
    final response = await _send(request);
    _check(response);
    return response.bodyBytes;
  }

  Future<String> _uploadPhoto(XFile file) async {
    final mime = await taskPhotoMimeType(file);
    final request = http.MultipartRequest('POST', _uri('photos'));
    request.headers.addAll(await _headers());
    request.followRedirects = false;
    request.files.add(
      await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: MediaType.parse(mime),
      ),
    );
    final response = await _send(request);
    return _data(response)['id'] as String;
  }

  Future<void> _deleteUnused(String id) async {
    final request =
        http.Request('DELETE', _uri('photos/${Uri.encodeComponent(id)}'))
          ..headers.addAll(await _headers())
          ..followRedirects = false;
    final response = await _send(request);
    // An attached or already deleted photo is unavailable for deletion.
    if (response.statusCode != 404) _check(response);
  }

  /// Call this from the authenticated planner repository. Pass its normal save
  /// or delete operation as [persist], and report any returned cleanup warning.
  Future<({T value, String? warning})> savePhotoChange<T>({
    required String? previousPhotoId,
    XFile? newPhoto,
    bool removePhoto = false,
    required Future<T> Function(String? photoId) persist,
  }) async {
    final uploaded = newPhoto == null ? null : await _uploadPhoto(newPhoto);
    final photoId = uploaded ?? (removePhoto ? null : previousPhotoId);
    final T saved;
    try {
      saved = await persist(photoId);
    } catch (_) {
      if (uploaded != null) {
        // The server refuses to delete a photo referenced by a committed entry.
        try {
          await _deleteUnused(uploaded);
        } catch (_) {
          // Preserve the original save error.
        }
      }
      rethrow;
    }

    String? warning;
    if (previousPhotoId != null && previousPhotoId != photoId) {
      try {
        await _deleteUnused(previousPhotoId);
      } catch (_) {
        warning = 'Task saved. The previous photo could not be cleaned up.';
      }
    }
    return (value: saved, warning: warning);
  }

  Map<String, dynamic> _data(http.Response response) {
    _check(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['data'] as Map<String, dynamic>;
  }

  void _check(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String? message;
    try {
      final body = jsonDecode(response.body);
      if (body is Map && body['error'] is Map) {
        final error = body['error'] as Map;
        final value = error['message'];
        if (value is String) message = value;
      }
    } on FormatException {
      // Infrastructure errors can return a non-JSON body.
    }
    throw EntryAttachmentException(
      response.statusCode,
      message ?? 'The attachment service is unavailable. Try again.',
    );
  }
}
