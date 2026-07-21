import 'base_result.dart';

class Success<Data> extends BaseResult<Data, Never> {
  final Data data;
  const Success(this.data);

  @override
  T when<T>({
    required T Function(Data data) success,
    required T Function(Never error) failure,
  }) {
    return success(data);
  }
}