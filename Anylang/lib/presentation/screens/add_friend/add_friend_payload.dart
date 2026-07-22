/// Qo'shish oynasi qayerdan ochilganiga qarab UI/logika.
enum AddFriendMode {
  /// Xabarlar "+" — natija ustiga bosilsa chat ochiladi.
  chat,

  /// Do'stlar "qo'shish" — so'rov yuborish / yuborildi / yozish tugmalari.
  friends,
}

class AddFriendPayload {
  final AddFriendMode mode;

  const AddFriendPayload({this.mode = AddFriendMode.chat});
}
