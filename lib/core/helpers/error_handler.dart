import 'dart:io';

/// Utility class for mapping technical exceptions to user-friendly messages.
class AppErrorHandler {
  /// Maps an exception to a user-friendly error message.
  static String getUserFriendlyMessage(dynamic error) {
    final errorString = error.toString().toLowerCase();

    // Network/Connection errors
    if (error is SocketException || 
        errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no internet')) {
      return 'Please check your internet connection and try again.';
    }

    // Timeout errors
    if (errorString.contains('timeout') || 
        errorString.contains('timed out')) {
      return 'The request timed out. Please try again.';
    }

    // Supabase/Postgres errors
    if (errorString.contains('postgrestexception') ||
        errorString.contains('postgresql')) {
      
      // Permission/Auth errors
      if (errorString.contains('not allowed') ||
          errorString.contains('permission denied') ||
          errorString.contains('rls') ||
          errorString.contains('policy')) {
        return 'You don\'t have permission to perform this action.';
      }
      
      // Not found
      if (errorString.contains('not found') ||
          errorString.contains('no rows')) {
        return 'The requested item was not found.';
      }

      // Duplicate/Conflict
      if (errorString.contains('duplicate') ||
          errorString.contains('unique constraint') ||
          errorString.contains('already exists')) {
        return 'This item already exists.';
      }

      // Foreign key violation
      if (errorString.contains('foreign key') ||
          errorString.contains('violates')) {
        return 'Cannot complete this action due to related data.';
      }

      return 'A database error occurred. Please try again.';
    }

    // Auth errors
    if (errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('unauthenticated') ||
        errorString.contains('invalid login') ||
        errorString.contains('invalid password')) {
      return 'Authentication failed. Please log in again.';
    }

    // Stock-specific errors
    if (errorString.contains('insufficient stock')) {
      // Extract the missing amount if present
      final regex = RegExp(r'missing (\d+) base units');
      final match = regex.firstMatch(errorString);
      if (match != null) {
        return 'Insufficient stock: ${match.group(1)} units short.';
      }
      return 'Insufficient stock to complete this operation.';
    }

    // Validation errors
    if (errorString.contains('qty_base_units must be > 0')) {
      return 'Quantity must be greater than zero.';
    }
    if (errorString.contains('expiry_date is required')) {
      return 'Please provide an expiry date.';
    }

    // Format/Parse errors
    if (errorString.contains('formatexception') ||
        errorString.contains('invalid format')) {
      return 'Invalid data format. Please check your input.';
    }

    // Generic fallback - don't show technical details
    return 'Something went wrong. Please try again.';
  }

  /// Returns true if the error is a network-related error
  static bool isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return error is SocketException ||
        errorString.contains('socketexception') ||
        errorString.contains('connection refused') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no internet') ||
        errorString.contains('timeout');
  }

  /// Returns true if the error is an authentication error
  static bool isAuthError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('auth') ||
        errorString.contains('unauthorized') ||
        errorString.contains('unauthenticated') ||
        errorString.contains('not allowed');
  }
}

/// A simple Result type for operations that can fail.
/// Use this instead of returning empty lists on error.
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final String message;
  final dynamic originalError;
  
  const Failure(this.message, [this.originalError]);
  
  /// Get a user-friendly message for display
  String get userMessage => AppErrorHandler.getUserFriendlyMessage(originalError ?? message);
}

/// Extension to easily check and unwrap Result
extension ResultExtension<T> on Result<T> {
  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  
  T? get dataOrNull => this is Success<T> ? (this as Success<T>).data : null;
  String? get errorOrNull => this is Failure<T> ? (this as Failure<T>).message : null;
  
  /// Execute different callbacks based on result
  R when<R>({
    required R Function(T data) success,
    required R Function(String message) failure,
  }) {
    return switch (this) {
      Success<T> s => success(s.data),
      Failure<T> f => failure(f.userMessage),
    };
  }
}
