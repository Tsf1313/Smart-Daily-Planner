import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smart_daily_planner/main.dart';
import 'package:smart_daily_planner/core/network/planner_client.dart';
import 'package:smart_daily_planner/core/storage/deadline_cache.dart';
import 'package:smart_daily_planner/features/dashboard/presentation/pages/dashboard_page.dart';

void main() {
  testWidgets('explains missing Firebase configuration', (tester) async {
    await tester.pumpWidget(
      const PlannerApp(setupMessage: 'Configure Firebase'),
    );
    expect(find.text('Configure Firebase'), findsOneWidget);
  });

  test('cache survives reopening and separates student accounts', () async {
    final root = await Directory.systemTemp.createTemp();
    addTearDown(() => root.delete(recursive: true));
    DeadlineCache cache(String uid) =>
        DeadlineCache(uid, directory: () async => root);
    await cache('alice')
        .save([const Deadline('1', 'MAD report', '2027-01-01')]);
    expect((await cache('alice').read())!.single.title, 'MAD report');
    expect(await cache('bob').read(), isNull);
  });

  testWidgets('loads an owned deadline then shows a read-only copy offline', (
    tester,
  ) async {
    var online = true;
    var status = 200;
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/entries');
      expect(request.headers['Authorization'], 'Bearer token');
      if (!online) throw http.ClientException('Offline');
      return http.Response(
        jsonEncode({
          'data': [
            {'id': '1', 'title': 'MAD report', 'dueDate': '2099-01-01'},
            {'id': '2', 'title': 'Old report', 'dueDate': '2001-01-01'},
          ],
        }),
        status,
      );
    });
    final api = PlannerClient(
      Uri.parse('https://example.test/api/v1/'),
      client,
      () async => 'token',
    );
    final cache = _MemoryCache();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DashboardPage(api: api, cache: cache),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('MAD report'), findsOneWidget);
    expect(find.text('Old report'), findsNothing);
    online = false;
    await tester.tap(find.byTooltip('Refresh deadlines'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Offline'), findsOneWidget);
    expect(find.text('MAD report'), findsOneWidget);
    online = true;
    status = 403;
    await tester.tap(find.byTooltip('Refresh deadlines'));
    await tester.pumpAndSettle();
    expect(find.text('MAD report'), findsNothing);
    expect(await cache.read(), isNull);
  });
}

class _MemoryCache extends DeadlineCache {
  _MemoryCache() : super('alice', directory: () async => Directory.systemTemp);
  List<Deadline>? rows;
  @override
  Future<void> save(List<Deadline> entries) async {
    rows = entries;
  }

  @override
  Future<List<Deadline>?> read() async => rows;
  @override
  Future<void> clear() async {
    rows = null;
  }
}
