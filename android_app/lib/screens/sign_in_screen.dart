import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, this.onContinueAsGuest});

  /// Shown on first launch; null when opened from Profile.
  final VoidCallback? onContinueAsGuest;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted && widget.onContinueAsGuest == null) Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: widget.onContinueAsGuest == null ? AppBar() : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: AppLogo(size: 72)),
                  const SizedBox(height: 16),
                  Text(_register ? 'Create your account' : 'Welcome to PlasticLens',
                      style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Sign in to back up your scans, collection and badges.', textAlign: TextAlign.center, style: t.bodyMedium),
                  const SizedBox(height: 24),
                  if (_register) ...[
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                    validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            if (!_form.currentState!.validate()) return;
                            _run(() => _register
                                ? auth.register(_name.text, _email.text, _password.text)
                                : auth.signInWithEmail(_email.text, _password.text));
                          },
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(_register ? 'Create account' : 'Sign in'),
                  ),
                  if (!_register)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (!_email.text.contains('@')) {
                                setState(() => _error = 'Enter your email above first.');
                                return;
                              }
                              await _run(() => auth.sendPasswordReset(_email.text));
                              if (context.mounted && _error == null) showSnack(context, 'Password reset email sent.');
                            },
                      child: const Text('Forgot password?'),
                    ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _run(auth.signInWithGoogle),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _busy ? null : () => setState(() => _register = !_register),
                    child: Text(_register ? 'I already have an account' : 'New here? Create an account'),
                  ),
                  if (widget.onContinueAsGuest != null) ...[
                    const Divider(height: 32),
                    TextButton(
                      onPressed: widget.onContinueAsGuest,
                      child: const Text('Continue without an account (scans stay on this phone)'),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
