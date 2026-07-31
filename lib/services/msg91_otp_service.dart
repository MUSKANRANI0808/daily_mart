import 'apitxt_otp_service.dart';

/// Legacy Wrapper - MSG91 removed and replaced completely with ApitxtOtpService
class Msg91OtpService {
  /// Send OTP using Apitxt.com API
  static Future<Map<String, dynamic>> sendOtp(String mobileNumber, {String? customTemplateId}) async {
    return await ApitxtOtpService.sendOtp(mobileNumber);
  }

  /// Verify OTP using Apitxt.com API
  static Future<Map<String, dynamic>> verifyOtp(String mobileNumber, String otpCode) async {
    return await ApitxtOtpService.verifyOtp(mobileNumber, otpCode);
  }

  /// Resend OTP using Apitxt.com API
  static Future<Map<String, dynamic>> resendOtp(String mobileNumber) async {
    return await ApitxtOtpService.resendOtp(mobileNumber);
  }
}
