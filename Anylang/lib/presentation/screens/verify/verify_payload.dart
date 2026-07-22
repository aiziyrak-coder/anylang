class VerifyPayload {
  final String email;
  /// SMTP yo‘q bo‘lganda server qaytargan tasdiqlash kodi.
  final String? debugOtp;

  const VerifyPayload({
    required this.email,
    this.debugOtp,
  });
}
