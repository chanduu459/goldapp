import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/auth_credentials.dart';

class AuthViewModel extends ChangeNotifier {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isPasswordHidden = true;
  bool isSubmitting = false;
  String? errorMessage;

  void togglePasswordVisibility() {
    isPasswordHidden = !isPasswordHidden;
    notifyListeners();
  }

  String? validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return 'Email is required';
    }
    if (!email.contains('@') || !email.contains('.')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? validatePassword(String? value) {
    final password = value ?? '';
    if (password.isEmpty) {
      return 'Password is required';
    }
    if (password.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  AuthCredentials get credentials => AuthCredentials(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

  Future<bool> signIn() async {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid || isSubmitting) {
      return false;
    }

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final creds = credentials;
      await Supabase.instance.client.auth.signInWithPassword(
        email: creds.email,
        password: creds.password,
      );

      isSubmitting = false;
      notifyListeners();
      return true;
    } on AuthException catch (e) {
      errorMessage = e.message;
    } catch (_) {
      errorMessage = 'Unable to sign in. Please try again.';
    }

    isSubmitting = false;
    notifyListeners();
    return false;
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}
