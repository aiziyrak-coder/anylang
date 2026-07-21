abstract class BaseResult<Data, Error> {
  const BaseResult();

  T when<T>({
    required T Function(Data data) success,
    required T Function(Error error) failure,
  });

  /// 🔥 Faqat successni qaytaradi (failure bo‘lsa null)
  Data? get dataOrNull => when(
    success: (data) => data,
    failure: (_) => null,
  );

  /// 🔥 Faqat errorni qaytaradi (success bo‘lsa null)
  Error? get errorOrNull => when(
    success: (_) => null,
    failure: (error) => error,
  );

  /// 🔥 Success bo‘lsa ishlaydi (side-effect uchun)
  void onSuccess(void Function(Data data) callback) {
    when(
      success: callback,
      failure: (_) {},
    );
  }

  /// 🔥 Failure bo‘lsa ishlaydi
  void onFailure(void Function(Error error) callback) {
    when(
      success: (_) {},
      failure: callback,
    );
  }
}