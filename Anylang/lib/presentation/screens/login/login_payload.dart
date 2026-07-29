/// Login: oddiy kirish yoki qo'shimcha hisob qo'shish.
class LoginPayload {
  /// true: mavjud hisobni park qilib yangi hisob qo'shiladi.
  final bool addAccount;
  /// Orqaga qaytganda tiklanadigan userId (addAccount).
  final int? restoreUserId;

  const LoginPayload({
    this.addAccount = false,
    this.restoreUserId,
  });
}
