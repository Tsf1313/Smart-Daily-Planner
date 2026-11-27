import 'dart:convert';
import 'dart:io';

import '../network/planner_client.dart';

class DeadlineCache {
  DeadlineCache(this.uid, {required this.directory});
  final String uid;
  final Future<Directory> Function() directory;

  Future<File> _file() async {
    final root = await directory();
    final key = base64Url.encode(utf8.encode(uid));
    return File('${root.path}/deadlines-$key.json');
  }

  Future<void> save(List<Deadline> entries) async {
    final file = await _file();
    final tmp = File(
      '${file.path}.tmp-${DateTime.now().microsecondsSinceEpoch}',
    );
    await tmp.writeAsString(
      jsonEncode(entries.map((e) => e.toJson()).toList()),
      flush: true,
    );
    await tmp.rename(file.path);
  }

  Future<List<Deadline>?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final rows = jsonDecode(await file.readAsString()) as List;
    return rows
        .map((e) => Deadline.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> clear() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}
