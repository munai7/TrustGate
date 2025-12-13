import 'package:flutter/material.dart';

import 'app_state.dart';
import 'shared_ui.dart';
import 'login_and_biometric.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // تحميل حالة المحاولة من التخزين المحلي
  await AttemptStorage.load(AppState.instance.currentAttempt);

  runApp(const TahqiqAbsherApp());
}

class TahqiqAbsherApp extends StatelessWidget {
  const TahqiqAbsherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'تيقّن ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.green,
        ),
      ),
      home: const LoginScreen(),
    );
  }
}