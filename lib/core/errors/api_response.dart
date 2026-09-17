import 'package:equatable/equatable.dart';

/// A generic wrapper for API responses that may carry an error.
///
/// Every Xtream Codes endpoint returns either valid JSON data
/// or an error object. This class standardizes the two paths.
class ApiResponse<T> extends Equatable {
  final T? data;
  final String? error;

  const ApiResponse({this.data, this.error});

  bool get isSuccess => error == null && data != null;

  @override
  List<Object?> get props => [data, error];
}
