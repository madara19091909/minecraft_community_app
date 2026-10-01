import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts low-level exceptions into messages that are safe to show to users.
class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is SocketException || error is TimeoutException) {
      return const AppFailure('No connection. Check your internet and try again.');
    }
    if (error is AuthException) {
      final m = error.message.toLowerCase();
      if (m.contains('invalid login')) {
        return const AppFailure('Incorrect email or password.');
      }
      return AppFailure(error.message);
    }
    if (error is PostgrestException) {
      if (error.code == 'P0001') return AppFailure(error.message);
      if (error.code == '42501') {
        return const AppFailure("You don't have permission to do that.");
      }
      return AppFailure('Request failed (${error.code ?? 'unknown'}).');
    }
    return const AppFailure('Something went wrong. Please try again.');
  }

  @override
  String toString() => message;
}
