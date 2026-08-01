class ManualRetryRequiredException implements Exception {
  const ManualRetryRequiredException();

  @override
  String toString() =>
      'ManualRetryRequiredException: retry the request explicitly.';
}
