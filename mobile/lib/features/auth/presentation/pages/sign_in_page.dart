import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/app_theme.dart';
import '../../../../core/widgets/planner_primary_button.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final name = TextEditingController();
  final confirmation = TextEditingController();
  bool resetting = false;
  String? success;
  bool register = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      success = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (resetting) {
        await auth.sendPasswordResetEmail(email: email.text.trim());
        if (mounted) {
          setState(
            () => success = 'Password reset link requested. Check your email.',
          );
        }
      } else if (register) {
        if (password.text != confirmation.text || name.text.trim().isEmpty) {
          if (mounted) {
            setState(() => error = 'Enter your name and matching passwords.');
          }
          return;
        }
        final result = await auth.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
        await result.user?.updateDisplayName(name.text.trim());
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

  void _show({bool createAccount = false, bool resetPassword = false}) {
    setState(() {
      register = createAccount;
      resetting = resetPassword;
      error = null;
      success = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final action = resetting
        ? 'Send Reset Link'
        : register
        ? 'Create Account'
        : 'Login';
    final login = !register && !resetting;
    return Scaffold(
      appBar: login
          ? null
          : AppBar(
              leading: IconButton(
                tooltip: 'Back to login',
                onPressed: busy ? null : () => _show(),
                icon: const Icon(Icons.arrow_back),
              ),
            ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (login)
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 38,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.gradientStart, AppColors.gradientEnd],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Column(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: Colors.white,
                      size: 34,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Welcome Back',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Sign in to continue planning',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                resetting ? 'Forgot Password?' : 'Create Account',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                resetting
                    ? 'Enter your registered email.'
                    : 'Join SmartPlan and start planning.',
              ),
            ],
            const SizedBox(height: 22),
            if (register) ...[
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email address',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            if (!resetting) ...[
              const SizedBox(height: 12),
              TextField(
                controller: password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
            if (register) ...[
              const SizedBox(height: 12),
              TextField(
                controller: confirmation,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
            if (login)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: busy ? null : () => _show(resetPassword: true),
                  child: const Text('Forgot Password?'),
                ),
              ),
            if (error case final String message)
              Text(message, style: const TextStyle(color: AppColors.error)),
            if (success case final String message)
              Text(message, style: const TextStyle(color: AppColors.success)),
            const SizedBox(height: 16),
            PlannerPrimaryButton(
              label: busy ? 'Please wait…' : action,
              onPressed: busy ? null : submit,
            ),
            TextButton(
              onPressed: busy ? null : () => _show(createAccount: login),
              child: Text(
                login ? 'Don’t have an account? Sign Up' : 'Back to Login',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
