import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../config.dart';

/// Sends notification emails via EmailJS — works from both the web app and
/// the Android app, so friends without the app open (or on iPhone, where
/// the web version has no push) still hear about requests and plans.
///
/// Quietly does nothing until the EmailJS ids are filled in AppConfig.
class EmailService {
  static Future<void> send({
    required String toEmail,
    required String toName,
    required String subject,
    required String message,
  }) async {
    if (!AppConfig.hasEmail || toEmail.isEmpty) return;
    try {
      final res = await http.post(
        Uri.parse('https://api.emailjs.com/api/v1.0/email/send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': AppConfig.emailJsServiceId,
          'template_id': AppConfig.emailJsTemplateId,
          'user_id': AppConfig.emailJsPublicKey,
          'template_params': {
            'to_email': toEmail,
            'to_name': toName,
            'subject': subject,
            'message': message,
          },
        }),
      );
      if (res.statusCode != 200) {
        debugPrint('email send failed (${res.statusCode}): ${res.body}');
      }
    } catch (e) {
      debugPrint('email send failed: $e');
    }
  }
}
