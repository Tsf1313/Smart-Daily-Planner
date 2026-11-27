import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.user});
  final User user;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final name = TextEditingController(text: widget.user.displayName ?? '');
  bool busy = false;
  String? message;

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> update({required bool signOut}) async {
    final displayName = name.text.trim();
    if (!signOut && displayName.isEmpty) {
      setState(() => message = 'Enter a display name.');
      return;
    }
    setState(() {
      busy = true;
      message = null;
    });
    try {
      if (signOut) {
        await FirebaseAuth.instance.signOut();
      } else {
        await widget.user.updateDisplayName(displayName);
        if (mounted) setState(() => message = 'Profile saved.');
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => message = e.message ?? 'Account update failed.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      ListTile(
        title: const Text('Email'),
        subtitle: Text(widget.user.email ?? ''),
      ),
      TextField(
        controller: name,
        maxLength: 100,
        decoration: const InputDecoration(labelText: 'Display name'),
      ),
      FilledButton(
        onPressed: busy ? null : () => update(signOut: false),
        child: const Text('Save profile'),
      ),
      if (message != null) Text(message!),
      OutlinedButton(
        onPressed: busy ? null : () => update(signOut: true),
        child: const Text('Sign out'),
      ),
    ],
  );
}
