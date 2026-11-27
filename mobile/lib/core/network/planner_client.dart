import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class Deadline {
  const Deadline(this.id, this.title, this.dueDate);
  final String id;
  final String title;
  final String dueDate;

  factory Deadline.fromJson(Map<String, dynamic> json) => Deadline(
    json['id'] as String,
    json['title'] as String,
    json['dueDate'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dueDate': dueDate,
  };
}

class ApiFailure implements Exception {
  const ApiFailure(this.status);
  final int status;
}

class PlannerClient {
  PlannerClient(this.baseUrl, this.client, this.idToken);
  final Uri baseUrl;
  final http.Client client;
  final Future<String?> Function() idToken;

  Future<List<Deadline>> deadlines() async {
    final token = await idToken().timeout(const Duration(seconds: 12));
    if (token == null) throw const ApiFailure(401);
    final uri = baseUrl.resolve('entries');
    final local = ['localhost', '127.0.0.1', '10.0.2.2'].contains(uri.host);
    if (uri.scheme != 'https' && !(uri.scheme == 'http' && local)) {
      throw StateError('Use HTTPS for a hosted API.');
    }
    final res = await client
        .get(uri, headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw ApiFailure(res.statusCode);
    final data = jsonDecode(utf8.decode(res.bodyBytes))['data'] as List;
    return data
        .map((e) => Deadline.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
