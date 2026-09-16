import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Severity of a surfaced error. Hard errors (load/provider failures) get the
/// blocking modal; transient retryable states use a snackbar instead.
enum AppErrorSeverity { warning, error, critical }

/// Where the modal's primary action should take the user.
enum AppErrorAction { none, review, heidesSetup }

class AppError {
  final String id;
  final String title;
  final String message;
  final AppErrorSeverity severity;
  final AppErrorAction action;
  final String? actionLabel;

  const AppError({
    required this.id,
    required this.title,
    required this.message,
    this.severity = AppErrorSeverity.error,
    this.action = AppErrorAction.review,
    this.actionLabel,
  });
}

/// One modal error at a time. Duplicates (same id) are ignored so a rebuild
/// never stacks modals.
class ErrorNotifier extends StateNotifier<AppError?> {
  ErrorNotifier() : super(null);

  void show(AppError error) {
    if (state?.id == error.id) return;
    state = error;
  }

  void dismiss() => state = null;
}

final errorProvider = StateNotifierProvider<ErrorNotifier, AppError?>((ref) {
  return ErrorNotifier();
});