import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/errors/app_failure.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _obscure = true;
  String? _error;

  static const _background = Color(0xFF050505);
  static const _field = Color(0xFF151515);
  static const _accent = Color(0xFFF0444A);

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await ref.read(authControllerProvider).signIn(
            _email.text,
            _password.text,
          );
    } catch (e) {
      if (mounted) {
        setState(() => _error = AppFailure.from(e).message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF8E8E8E),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: const Color(0xFF9A9A9A), size: 24),
      suffixIcon: suffix,
      filled: true,
      fillColor: _field,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF2B2B2B)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFF2B2B2B)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: _accent, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE04B50)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: const BorderSide(color: Color(0xFFE04B50), width: 1.4),
      ),
      errorStyle: const TextStyle(height: 1.15),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;
          final headerHeight = (height * 0.38).clamp(300.0, 410.0);

          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  'assets/login_background.jpg',
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.30, 0.50, 0.70, 1.0],
                        colors: const [
                          Color(0x14000000),
                          Color(0x18000000),
                          Color(0x50000000),
                          Color(0xD9050505),
                          Color(0xFF050505),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: (height * 0.30).clamp(250.0, 390.0)),
                        Text(
                          'Welcome back',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white,
                            fontSize: 36,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.8,
                            shadows: const [
                              Shadow(
                                blurRadius: 16,
                                color: Colors.black87,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'mcc  •  Minecraft Community',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 42),
                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.email],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _inputDecoration(
                                  hint: 'Email address',
                                  icon: Icons.mail_outline_rounded,
                                ),
                                validator: (value) =>
                                    (value == null || !value.contains('@'))
                                        ? 'Enter a valid email address'
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _submit(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: _inputDecoration(
                                  hint: 'Password',
                                  icon: Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    tooltip: _obscure
                                        ? 'Show password'
                                        : 'Hide password',
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: const Color(0xFF8E8E8E),
                                    ),
                                    onPressed: () => setState(
                                      () => _obscure = !_obscure,
                                    ),
                                  ),
                                ),
                                validator: (value) =>
                                    (value == null || value.length < 6)
                                        ? 'Password must be at least 6 characters'
                                        : null,
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0x26F0444A),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0x66F0444A),
                                    ),
                                  ),
                                  child: Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFFF8A8E),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 58,
                                child: ElevatedButton(
                                  onPressed: _busy ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _accent,
                                    disabledBackgroundColor:
                                        _accent.withOpacity(0.55),
                                    foregroundColor: Colors.white,
                                    elevation: 8,
                                    shadowColor: _accent.withOpacity(0.28),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 180),
                                    child: _busy
                                        ? const SizedBox(
                                            key: ValueKey('loading'),
                                            width: 23,
                                            height: 23,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Sign in',
                                            key: const ValueKey('sign-in'),
                                            style: GoogleFonts.spaceGrotesk(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 22),
                              Text(
                                'Use your approved mcc account to continue.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.spaceGrotesk(
                                  color: const Color(0xFF777777),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
