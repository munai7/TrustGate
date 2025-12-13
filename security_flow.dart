import 'dart:math';
import 'package:flutter/material.dart';

import 'shared_ui.dart';
import 'app_state.dart';

/// شاشة التنبيه الأمني
class SecurityAlertScreen extends StatefulWidget {
  const SecurityAlertScreen({super.key});

  @override
  State<SecurityAlertScreen> createState() => _SecurityAlertScreenState();
}

class _SecurityAlertScreenState extends State<SecurityAlertScreen> {
  AttemptModel? attemptData;
  bool loading = true;

  @override
  void initState() {
    super.initState();

    // إعادة تعيين بيانات المحاولة
    final attempt = AppState.instance.currentAttempt;
    attempt.failedCodeTries = 0;
    attempt.locked = false;
    AttemptStorage.reset();

    loadAttempt();
  }

  Future<void> loadAttempt() async {
    final data = await ApiService.fetchLastAttempt();
    setState(() {
      attemptData = data;
      loading = false;
    });
  }

  /// نستخدمه كـ request_id عند إرسال القرار
  String get _requestId =>
      attemptData?.requestId ?? AppState.instance.currentAttempt.attemptId;


  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.green),
            )
          : attemptData == null
              ? const Center(
                  child: Text(
                    'لا توجد محاولة تسجيل دخول مشبوهة.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    const AppHeader(title: 'تنبيه أمني'),
                    const SizedBox(height: 10),

                    // بطاقة تفاصيل المحاولة
                    _buildSuspiciousAttemptCard(attemptData!),

                    const SizedBox(height: 20),

                    PrimaryButton(
                      text: 'السماح',
                      verticalPadding: 11,
                      onPressed: () => _showConfirmDialog('accept'),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.red,
                          side: const BorderSide(color: AppColors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => _showConfirmDialog('deny'),
                        child: const Text(
                          'رفض',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSuspiciousAttemptCard(AttemptModel data) {
    final service = data.serviceName ?? 'خدمة غير معروفة';
    final riskLevel = data.riskLevel ?? 'Unknown';
    final riskReason = data.riskReason ?? 'Unknown';
    final riskDetails = data.riskDetails ?? '';
    final previousLocation = data.previousLocation;
    final currentLocation = data.currentLocation;
    final ip = data.ipAddress ?? 'غير متوفر';
    final device = data.deviceInfo ?? 'غير معروف';
    final time = data.createdAt ?? '';

    String readableTime = time.isNotEmpty
        ? (DateTime.tryParse(time)?.toLocal().toString().substring(0, 16) ??
            time)
        : 'غير معروف';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "تفاصيل محاولة تسجيل الدخول",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          Text("الخدمة: $service"),
          const SizedBox(height: 6),

          Text(
            "مستوى الخطورة: $riskLevel",
            style: TextStyle(
              color: Colors.red[700],
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),

          Text("سبب الاشتباه: $riskReason"),
          const SizedBox(height: 6),

          if (riskDetails.isNotEmpty)
            Text(
              riskDetails,
              style: TextStyle(color: Colors.grey[700]),
            ),

          if (riskReason == "Impossible_Travel" &&
              previousLocation != null &&
              currentLocation != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("من: $previousLocation"),
                  Text("إلى: $currentLocation"),
                ],
              ),
            ),

          const SizedBox(height: 10),
          Divider(color: Colors.grey[300]),
          const SizedBox(height: 8),

          Text("الجهاز: $device"),
          Text("عنوان IP: $ip"),
          Text("الوقت: $readableTime"),
        ],
      ),
    );
  }

  void _showConfirmDialog(String action) {
    final isAccept = action == 'accept';

    final title = isAccept ? 'تأكيد قبول المحاولة' : 'تأكيد رفض المحاولة';
    final body = isAccept
        ? 'هل أنت متأكدة من قبول هذه المحاولة؟'
        : 'هل أنت متأكدة من رفض هذه المحاولة؟ سيتم حظر الجلسة.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(title),
            content: Text(
              body,
              style: const TextStyle(height: 1.7),
            ),
            actions: [
              Column(
                children: [
                  PrimaryButton(
                    text: isAccept ? 'تأكيد القبول' : 'تأكيد الرفض',
                    verticalPadding: 11,
                    onPressed: () async {
                      Navigator.pop(context);

                      if (isAccept) {
                        final correctCode =
                            attemptData?.matchingCode ?? '37';

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => MatchingCodeScreen(
                              correctCode: correctCode,
                              requestId: _requestId,
                            ),
                          ),
                        );
                      } else {
                        await ApiService.sendDecision(
                          requestId: _requestId,
                          decision: 'deny',
                        );

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ResultScreen(approved: false),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 6),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}

/// ===============================================
/// ========== شاشة الماتش كود =====================
/// ===============================================

class MatchingCodeScreen extends StatefulWidget {
  final String correctCode;
  final String requestId;

  const MatchingCodeScreen({
    super.key,
    required this.correctCode,
    required this.requestId,
  });

  @override
  State<MatchingCodeScreen> createState() => _MatchingCodeScreenState();
}

class _MatchingCodeScreenState extends State<MatchingCodeScreen> {
  String? _errorText;
  late List<String> _codes;

  @override
  void initState() {
    super.initState();
    _generateCodes();
  }

  void _generateCodes() {
    final rnd = Random();
    final set = <String>{widget.correctCode};

    while (set.length < 3) {
      final code = (10 + rnd.nextInt(90)).toString();
      set.add(code);
    }

    _codes = set.toList()..shuffle();
  }

  Future<void> _checkCode(String chosen) async {
    final attempt = AppState.instance.currentAttempt;

    if (attempt.locked) {
      setState(() {
        _errorText = 'تم حظر هذه المحاولة.';
      });
      return;
    }

    if (chosen == widget.correctCode) {
      attempt.failedCodeTries = 0;
      attempt.locked = false;
      await AttemptStorage.save(attempt);

      await ApiService.sendDecision(
        requestId: widget.requestId,
        decision: 'allow',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const ResultScreen(approved: true),
        ),
      );
    } else {
      attempt.failedCodeTries++;
      if (attempt.failedCodeTries >= 3) {
        attempt.locked = true;
        await AttemptStorage.save(attempt);

        await ApiService.sendDecision(
          requestId: widget.requestId,
          decision: 'deny',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حظر المحاولة بعد 3 محاولات خاطئة.'),
          ),
        );
        Navigator.pop(context);
      } else {
        await AttemptStorage.save(attempt);
        setState(() {
          _errorText =
              'الرمز غير صحيح. تبقى ${3 - attempt.failedCodeTries} محاولات.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppShell(
      child: Column(
        children: [
          const SizedBox(height: 4),
          const AppHeader(title: 'تيقّن'),
          const SizedBox(height: 10),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text(
                    'رقم الطلب',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'فضلاً اختيار رقم الطلب الظاهر لدى مزود الخدمة.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textMuted),
                  ),

                  const SizedBox(height: 18),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: _codes
                        .map(
                          (c) => CodeBubble(
                            text: c,
                            onTap: () => _checkCode(c),
                          ),
                        )
                        .toList(),
                  ),

                  const SizedBox(height: 10),
                  if (_errorText != null)
                    Text(
                      _errorText!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.red,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===============================================
/// ============ شاشة النتيجة =======================
/// ===============================================

class ResultScreen extends StatelessWidget {
  final bool approved;

  const ResultScreen({super.key, required this.approved});

  @override
  Widget build(BuildContext context) {
    final iconColor = approved ? AppColors.green : AppColors.red;
    final icon = approved ? Icons.check : Icons.close;
    final title =
        approved ? 'تم قبول محاولة الدخول' : 'تم رفض محاولة الدخول';
    final text = approved
        ? 'تم تأكيد طلب تسجيل الدخول على حسابك في أبشر بنجاح عبر نظام "تيقّن"، وتم تحديث حالة الجلسة.'
        : 'تم رفض محاولة تسجيل الدخول المشبوهة عبر نظام "تيقّن"، وتم حظر هذه الجلسة لحماية حسابك.\nننصحك بمراجعة نشاط حسابك وتغيير كلمة المرور إذا لم تكن أنت من حاول تسجيل الدخول.';

    // 🔹 إضافة جلسة جديدة فقط إذا كانت المحاولة مقبولة
    if (approved) {
      final sessions = AppState.instance.sessions;
      final alreadyExists = sessions.any((s) => s.id == 'S-001');

      if (!alreadyExists) {
        sessions.add(
          SessionItem(
            title: 'Chrome على Windows',
            subtitle: 'الرياض • آخر نشاط: قبل لحظات',
            status: 'جلسة حالية',
            statusColor: AppColors.green,
            id: 'S-001',
          ),
        );
      }
    }

    return AppShell(
      child: Column(
        children: [
          const SizedBox(height: 4),
          const AppHeader(title: 'حالة محاولة الدخول'),
          const SizedBox(height: 10),

          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // رمز النجاح / الرفض
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: iconColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textMuted,
                      height: 1.7,
                    ),
                  ),

                  const SizedBox(height: 10),
                  Text(
                    approved
                        ? 'رقم المحاولة: TA-2025-00123'
                        : 'رقم المحاولة: TA-2025-00123 (مرفوضة)',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),

                  // 🔹 زر إدارة الجلسات يظهر فقط إذا كانت المحاولة مقبولة
                  if (approved) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SessionsScreen(),
                            ),
                          );
                        },
                        child: const Text('عرض الجلسات النشطة'),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storedSessions = AppState.instance.sessions;

    final sessions = storedSessions.isEmpty
        ? <SessionItem>[
            SessionItem(
              title: 'Chrome على Windows',
              subtitle: 'الرياض • آخر نشاط: قبل 5 دقائق',
              status: 'جلسة حالية',
              statusColor: AppColors.green,
              id: 'S-001',
            ),
            SessionItem(
              title: 'Safari على iPhone',
              subtitle: 'الدمام • آخر نشاط: قبل ساعتين',
              status: 'جلسة قديمة',
              statusColor: AppColors.risk,
              id: 'S-002',
            ),
          ]
        : storedSessions;

    return AppShell(
      child: Column(
        children: [
          const SizedBox(height: 4),
          const AppHeader(title: 'إدارة الجلسات'),
          const SizedBox(height: 10),
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الجلسات النشطة على حسابك',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Divider(),
                  for (final s in sessions) ...[
                    _SessionRow(item: s),
                    if (s != sessions.last) const Divider(),
                  ],
                  const SizedBox(height: 8),
                  const Text(
                    'يمكنك إنهاء أي جلسة لا تتعرف عليها كإجراء احترازي لحماية حسابك.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final SessionItem item;

  const _SessionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.status,
                  style: TextStyle(
                    fontSize: 11,
                    color: item.statusColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إرسال طلب إنهاء الجلسة (${item.id}) ',
                  ),
                ),
              );
            },
            child: const Text(
              'إنهاء',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
