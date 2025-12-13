import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// كائن المحاولة الحالية (لـ rate limiting على الماتش كود)
class AuthAttempt {
  String attemptId;
  int failedCodeTries;
  bool locked;

  AuthAttempt({
    required this.attemptId,
    this.failedCodeTries = 0,
    this.locked = false,
  });
}

/// حالة التطبيق (محاولة حالية + الجلسات)
class AppState {
  AppState._();

  static final AppState instance = AppState._();

  final AuthAttempt currentAttempt =
      AuthAttempt(attemptId: 'TA-2025-00123');

  final List<SessionItem> sessions = [];
}

/// موديل يمثل آخر محاولة رجعت من FastAPI
class AttemptModel {
  final String attemptId;
  final String? requestId;        // 👈 جديد
  final String? serviceName;
  final String? riskLevel;
  final String? riskReason;
  final String? riskDetails;
  final String? previousLocation;
  final String? currentLocation;
  final String? ipAddress;
  final String? deviceInfo;
  final String? createdAt;
  final String? matchingCode;

  AttemptModel({
    required this.attemptId,
    this.requestId,               // 👈 جديد
    this.serviceName,
    this.riskLevel,
    this.riskReason,
    this.riskDetails,
    this.previousLocation,
    this.currentLocation,
    this.ipAddress,
    this.deviceInfo,
    this.createdAt,
    this.matchingCode,
  });

  factory AttemptModel.fromJson(Map<String, dynamic> json) {
    return AttemptModel(
      attemptId: json['attemptId'] ?? '',
      requestId: json['request_id'],   // 👈 يقرأ من الـ API
      serviceName: json['serviceName'],
      riskLevel: json['riskLevel'],
      riskReason: json['riskReason'],
      riskDetails: json['riskDetails'],
      previousLocation: json['previousLocation'],
      currentLocation: json['currentLocation'],
      ipAddress: json['ipAddress'],
      deviceInfo: json['deviceInfo'],
      createdAt: json['createdAt'],
      matchingCode: json['matchingCode'],
    );
  }
}

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:5000';

  static Future<AttemptModel?> fetchLastAttempt() async {
  try {
    final url = Uri.parse('$baseUrl/attempts/last');
    print('🚀 Calling: $url');   
    final res = await http.get(url);

    print('📡 Status Code: ${res.statusCode}');
    print('📦 Response Body: ${res.body}');

    if (res.statusCode != 200) return null;

    final data = json.decode(res.body);

    if (data is Map && data['status'] == 'empty') {
      print('⚠️ No suspicious attempt saved yet');
      return null;
    }

    return AttemptModel.fromJson(data as Map<String, dynamic>);
  } catch (e, st) {
    print('❌ Error in fetchLastAttempt: $e');
    print(st);
    return null;
  }
}

  static sendDecision({required String requestId, required String decision}) {}
}



/// تخزين حالة القفل وعدد المحاولات في SharedPreferences
class AttemptStorage {
  static const _keyLocked = 'attempt_locked';
  static const _keyFailedTries = 'attempt_failed_tries';

  static Future<void> save(AuthAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLocked, attempt.locked);
    await prefs.setInt(_keyFailedTries, attempt.failedCodeTries);
  }

  static Future<void> load(AuthAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    attempt.locked = prefs.getBool(_keyLocked) ?? false;
    attempt.failedCodeTries = prefs.getInt(_keyFailedTries) ?? 0;
  }

  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLocked);
    await prefs.remove(_keyFailedTries);
  }
}

/// الجلسات اللي تظهر في صفحة "إدارة الجلسات"
class SessionItem {
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final String id;

  const SessionItem({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    required this.id,
  });
}