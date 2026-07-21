import 'base_result.dart';

class Error<ErrorData> extends BaseResult<Never, ErrorData> {
  final ErrorData error;
  const Error(this.error);

  @override
  T when<T>({
    required T Function(Never data) success,
    required T Function(ErrorData error) failure,
  }) {
    return failure(error);
  }
}