import 'package:flutter/material.dart';
import 'shared_ui.dart';
import 'security_flow.dart';

/// شاشة تسجيل الدخول
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userController = TextEditingController();
  final _passController = TextEditingController();

  final String demoUser = '2233445566';
  final String demoPass = 'Test@1234';

  @override
  void dispose() {
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    final user = _userController.text.trim();
    final pass = _passController.text;

    if (user == demoUser && pass == demoPass) {
      // نجاح → نروح لصفحة البصمة
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BiometricScreen(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'بيانات الدخول غير صحيحة.\nللتجربة: 2233445566 / Test@1234',
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                ' تيقّن ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              _FormField(
                label: 'رقم الهوية / اسم المستخدم',
                hint: '',
                controller: _userController,
              ),
              const SizedBox(height: 10),
              _FormField(
                label: 'كلمة المرور',
                hint: '',
                obscure: true,
                controller: _passController,
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 0),
                  ),
                  onPressed: () {},
                  child: const Text(
                    'نسيت كلمة المرور؟',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              PrimaryButton(
                text: 'تسجيل الدخول',
                onPressed: _handleLogin,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final bool obscure;
  final TextEditingController? controller;

  const _FormField({
    required this.label,
    required this.hint,
    this.obscure = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFFFAFAFA),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green),
            ),
          ),
        ),
      ],
    );
  }
}

/// صفحة البصمة (MFA) – محاكاة بدون local_auth
class BiometricScreen extends StatefulWidget {
  const BiometricScreen({super.key});

  @override
  State<BiometricScreen> createState() => _BiometricScreenState();
}

class _BiometricScreenState extends State<BiometricScreen> {
  bool _loading = false;

  Future<void> _simulateBiometricSuccess() async {
    setState(() {
      _loading = true;
    });

    // نحاكي التحقق بالبصمة (تقريباً ثانية وحدة)
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _loading = false;
    });

    // بعد "نجاح" البصمة ننتقل للتنبيه الأمني (تيقّن)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const SecurityAlertScreen(),
      ),
    );
  }

  void _skip() {
    // تخطي خطوة البصمة والانتقال مباشرة لتيقّن
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const SecurityAlertScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FBF9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFFD3E6DA),
                            width: 2,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.fingerprint,
                            size: 120,
                            color: AppColors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'المصادقة بالبصمة',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'لأغراض العرض في الهاكاثون يتم محاكاة تحقق البصمة، ثم الانتقال إلى التحقق عبر "تيقّن".',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
                // زر تأكيد بالبصمة (محاكاة)
                PrimaryButton(
                  text: _loading ? 'جاري التحقق...' : 'تأكيد بالبصمة',
                  verticalPadding: 14,
                  onPressed: () {
                    if (_loading) return;      // إذا لسه جاري التحقق، لا تسوي شيء
                    _simulateBiometricSuccess(); // غير كذا شغّل المحاكاة
                  },
                ),
                const SizedBox(height: 10),
                // زر التخطي
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _skip,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.green),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      'تخطي',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}