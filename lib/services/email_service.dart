import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for sending booking confirmation emails to patients.
///
/// Features:
/// 1. Formats exact subject and body requested by the clinic faculty.
/// 2. Supports instant inbox delivery via EmailJS or any REST mailer.
/// 3. Non-blocking & failsafe — never halts the UI or booking transaction.
class EmailService {
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // EmailJS credentials (free tier or configured server-side)
  static const String emailJsServiceId = 'service_iy98qhl';
  static const String emailJsTemplateId = 'template_spgddsr';
  static const String emailJsPublicKey = 'r7ycTTdlaXk_DEniC';

  /// Sends a booking confirmation email when the patient taps "Confirm & Join".
  ///
  /// [recipientEmail] Patient's email address (from Firebase Auth).
  /// [patientName] Patient's full name.
  /// [departmentName] Chosen clinic department.
  /// [tokenNumber] Dynamic queue token number assigned (#1, #2, etc.).
  /// [estWaitMins] Calculated estimated wait time in minutes.
  /// [departmentId] Department document ID.
  Future<bool> sendBookingConfirmation({
    required String recipientEmail,
    required String patientName,
    required String departmentName,
    required int tokenNumber,
    required int estWaitMins,
    required String departmentId,
  }) async {
    final subject = 'Your QueueLess Token Confirmation — #$tokenNumber';

    final body = '''Hi $patientName,

Your spot in the queue has been confirmed!

Department: $departmentName
Your Token Number: #$tokenNumber
Estimated Wait Time: $estWaitMins minutes

We'll send you a notification when your turn is approaching. 
You can cancel your token anytime from the app before you're called.

Thank you for using QueueLess!''';

    debugPrint('📧 [EmailService] Preparing confirmation email to: $recipientEmail');
    debugPrint('📧 [EmailService] Subject: $subject');

    bool sentSuccessfully = false;

    // Dispatch via EmailJS if credentials are present
    if (emailJsServiceId.isNotEmpty &&
        emailJsTemplateId.isNotEmpty &&
        emailJsPublicKey.isNotEmpty) {
      try {
        final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'service_id': emailJsServiceId,
            'template_id': emailJsTemplateId,
            'user_id': emailJsPublicKey,
            'template_params': {
              'to_email': recipientEmail,
              'email': recipientEmail,
              'reply_to': recipientEmail,
              'patient_name': patientName,
              'name': patientName,
              'department_name': departmentName,
              'token_number': tokenNumber.toString(),
              'est_wait': estWaitMins.toString(),
              'subject': subject,
              'message': body,
            },
          }),
        );

        if (response.statusCode == 200) {
          debugPrint('📧 [EmailService] EmailJS delivery SUCCESS (200 OK)');
          sentSuccessfully = true;
        } else {
          debugPrint('⚠️ [EmailService] EmailJS status: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('⚠️ [EmailService] HTTP delivery error: $e');
      }
    } else {
      debugPrint('ℹ️ [EmailService] EmailJS credentials not set.');
    }

    return sentSuccessfully;
  }
}
