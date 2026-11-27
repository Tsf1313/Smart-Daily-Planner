import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../../../core/network/planner_client.dart';
import '../../../../core/storage/deadline_cache.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api, required this.cache});
  final PlannerClient api;
  final DeadlineCache cache;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<Deadline> entries = [];
  String? notice;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      notice = null;
      entries = [];
    });
    try {
      final fresh = await widget.api.deadlines();
      if (!mounted) return;
      entries = fresh;
      try {
        await widget.cache.save(fresh);
      } on FileSystemException {
        notice = 'Loaded deadlines. Offline saving is unavailable.';
      }
    } catch (e) {
      debugPrint('Dashboard load failed: ${e.runtimeType}: $e');
      if (!mounted) return;
      final offline =
          e is TimeoutException ||
          e is SocketException ||
          e is http.ClientException ||
          (e is FirebaseAuthException && e.code == 'network-request-failed');
      if (offline) {
        try {
          final saved = await widget.cache.read();
          entries = saved ?? [];
          notice = saved == null
              ? 'Offline. Open the dashboard online to save a copy.'
              : 'Offline · Showing your last saved deadlines';
        } catch (_) {
          notice = 'Your saved deadlines could not be opened.';
        }
      } else if (e is ApiFailure && (e.status == 401 || e.status == 403)) {
        notice = 'Access denied. Check your account or sign in again.';
        try {
          await widget.cache.clear();
        } on FileSystemException {
          /* Keep access blocked. */
        }
      } else {
        notice = 'Could not load deadlines. Check the server and try again.';
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final upcoming = entries.where((entry) {
      final date = DateTime.tryParse(entry.dueDate);
      if (date == null) return false;

      final dateOnly = date.toIso8601String().split('T').first;
      return dateOnly == entry.dueDate && !date.isBefore(today);
    }).toList();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Upcoming deadlines',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              tooltip: 'Refresh deadlines',
              onPressed: load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        if (notice != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(notice!),
          ),
        if (upcoming.isEmpty &&
            (notice == null ||
                entries.isNotEmpty ||
                notice!.startsWith('Offline ·')))
          const Text('No upcoming deadlines.'),
        for (final e in upcoming)
          ListTile(title: Text(e.title), subtitle: Text('Due ${e.dueDate}')),
      ],
    );
  }
}
