import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (register) {
        await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await auth.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? 'Authentication failed.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = register ? 'Create account' : 'Sign in';
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Daily Planner')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(action, style: Theme.of(context).textTheme.headlineMedium),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
            onSubmitted: (_) => submit(),
          ),
          if (error != null) Text(error!),
          const SizedBox(height: 20),
          FilledButton(onPressed: busy ? null : submit, child: Text(action)),
          TextButton(
            onPressed: busy
                ? null
                : () => setState(() {
                    register = !register;
                    error = null;
                  }),
            child: Text(
              register
                  ? 'Already registered? Sign in'
                  : 'Create a student account',
            ),
          ),
        ],
      ),
    );
  }
}
