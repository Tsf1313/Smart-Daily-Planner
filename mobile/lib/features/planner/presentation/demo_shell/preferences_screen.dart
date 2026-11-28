import 'package:material_ui/material_ui.dart';
import '../../../../app/app_theme.dart';
import '../../data/repositories/task_store.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = TaskStore.instance;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('App Preferences'),
        backgroundColor: AppColors.surface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionHeader('NOTIFICATIONS & REMINDERS'),
              _card(
                children: [
                  SwitchListTile.adaptive(
                    value: store.notificationsEnabled,
                    activeColor: AppColors.primary,
                    title: const Text('Task Reminders',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: const Text('Receive local alerts before deadlines & routines',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    onChanged: (val) => store.updatePreferences(notificationsEnabled: val),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    title: const Text('Default Reminder Time',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text(
                      store.defaultReminderMinutes == null
                          ? 'Off'
                          : '${store.defaultReminderMinutes} minutes before',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary),
                    ),
                    trailing: DropdownButton<int?>(
                      value: store.defaultReminderMinutes,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: null, child: Text('Off')),
                        DropdownMenuItem(value: 15, child: Text('15 min')),
                        DropdownMenuItem(value: 30, child: Text('30 min')),
                      ],
                      onChanged: store.notificationsEnabled
                          ? (val) {
                              if (val == null) {
                                store.updatePreferences(clearDefaultReminder: true);
                              } else {
                                store.updatePreferences(defaultReminderMinutes: val);
                              }
                            }
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _sectionHeader('CALENDAR'),
              _card(
                children: [
                  SwitchListTile.adaptive(
                    value: store.weekStartsMonday,
                    activeColor: AppColors.primary,
                    title: const Text('Start Week on Monday',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text(
                      store.weekStartsMonday ? 'Monday – Sunday' : 'Sunday – Saturday',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onChanged: (val) => store.updatePreferences(weekStartsMonday: val),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              _sectionHeader('OFFLINE & STORAGE'),
              _card(
                children: [
                  SwitchListTile.adaptive(
                    value: store.offlineMode,
                    activeColor: AppColors.warning,
                    title: const Text('Simulate Offline Read-Only Mode',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: const Text(
                      'Preview how cached tasks appear when internet is unavailable',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    onChanged: (val) => store.updatePreferences(offlineMode: val),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cleaning_services_outlined, color: AppColors.primary),
                    title: const Text('Clear Cached Data',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: const Text('Refresh local SQLite cache from server',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Local cache cleared.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}
