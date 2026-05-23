enum RootDirectoryStatus { initial, loading, ready, error }

class RootDirectoryState {
  const RootDirectoryState({
    this.status = RootDirectoryStatus.initial,
    this.path,
    this.errorMessage,
  });

  final RootDirectoryStatus status;
  final String? path;
  final String? errorMessage;

  bool get hasRoot =>
      path != null && path!.isNotEmpty && status != RootDirectoryStatus.error;

  RootDirectoryState copyWith({
    RootDirectoryStatus? status,
    String? path,
    String? errorMessage,
    bool clearPath = false,
    bool clearError = false,
  }) {
    return RootDirectoryState(
      status: status ?? this.status,
      path: clearPath ? null : (path ?? this.path),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

}
