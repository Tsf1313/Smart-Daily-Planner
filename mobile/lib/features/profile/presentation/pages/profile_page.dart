import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/planner_primary_button.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user, this.beforeSignOut});
  final User user;
  final Future<void> Function()? beforeSignOut;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _signingOut = false;

  String get _displayName => widget.user.displayName?.trim().isNotEmpty == true
      ? widget.user.displayName!
      : 'Student';

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await widget.beforeSignOut?.call();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not sign out. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.gradientStart, AppColors.gradientEnd],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              CircleAvatar(
                backgroundColor: Colors.white24,
                foregroundColor: Colors.white,
                child: Text(_displayName.characters.first.toUpperCase()),
              ),
              const SizedBox(height: 8),
              Text(
                _displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                widget.user.email ?? '',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Card(
          color: AppColors.surface,
          elevation: 0,
          child: ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.primary),
            title: const Text('Edit Profile'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _signingOut
                ? null
                : () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _EditProfilePage(
                          user: widget.user,
                          displayName: _displayName,
                        ),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: _signingOut ? null : _signOut,
          icon: const Icon(Icons.logout),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }
}

class _EditProfilePage extends StatefulWidget {
  const _EditProfilePage({required this.user, required this.displayName});
  final User user;
  final String displayName;

  @override
  State<_EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<_EditProfilePage> {
  late final _name = TextEditingController(text: widget.user.displayName ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.user.updateDisplayName(name);
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        setState(() => _error = error.message ?? 'Could not save profile.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 34,
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Text(widget.displayName.characters.first.toUpperCase()),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _name,
            maxLength: 100,
            decoration: InputDecoration(labelText: 'Name', errorText: _error),
          ),
          const SizedBox(height: 8),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Email address'),
            child: Text(widget.user.email ?? ''),
          ),
          const SizedBox(height: 24),
          PlannerPrimaryButton(
            label: 'Save Changes',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
