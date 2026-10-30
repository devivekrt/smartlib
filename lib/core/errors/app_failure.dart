sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

class NetworkFailure extends AppFailure {
  const NetworkFailure([super.message = 'Network connection failed.']);
}

class BackendFailure extends AppFailure {
  const BackendFailure([super.message = 'The server could not complete the request.']);
}

class DataFailure extends AppFailure {
  const DataFailure([super.message = 'The received data is invalid.']);
}
