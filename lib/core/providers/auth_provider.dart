import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/user_model.dart';
import 'firestore_provider.dart';
import 'follow_provider.dart';
import 'interaction_provider.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? error;
  final bool isGuest;
  final bool isInitializing;
  // Set while waiting for the user to enter the SMS code.
  final String? phoneVerificationId;
  // True when the OTP was requested for account linking (not new sign-in).
  final bool isLinkingPhone;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.error,
    this.isGuest = false,
    this.isInitializing = false,
    this.phoneVerificationId,
    this.isLinkingPhone = false,
  });

  bool get isAuthenticated => user != null || isGuest;
  bool get awaitingOtp => phoneVerificationId != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? error,
    bool? isGuest,
    bool? isInitializing,
    String? phoneVerificationId,
    bool? isLinkingPhone,
    bool clearError = false,
    bool clearUser = false,
    bool clearVerificationId = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isGuest: isGuest ?? this.isGuest,
      isInitializing: isInitializing ?? this.isInitializing,
      phoneVerificationId: clearVerificationId
          ? null
          : (phoneVerificationId ?? this.phoneVerificationId),
      isLinkingPhone: isLinkingPhone ?? this.isLinkingPhone,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final firebaseUser = fb.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      Future.microtask(() => _restoreSession(firebaseUser.uid));
      return const AuthState(isInitializing: true);
    }
    return const AuthState(isInitializing: false);
  }

  Future<void> _restoreSession(String uid) async {
    final service = ref.read(firestoreServiceProvider);
    final user = await service.getUserById(uid);
    state = AuthState(isInitializing: false, user: user);
  }

  // ── Email / password ───────────────────────────────────────────────────────

  Future<void> loginWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    if (email.isEmpty || password.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'Please fill in all fields');
      return;
    }
    try {
      final credential = await fb.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      final user =
          await ref.read(firestoreServiceProvider).getUserById(credential.user!.uid);
      state = state.copyWith(
        isLoading: false,
        user: user,
        isInitializing: false,
      );
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong. Please try again.');
    }
  }

  Future<void> register(String username, String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    final u = username.trim().toLowerCase();
    if (u.isEmpty || email.isEmpty || password.isEmpty) {
      state = state.copyWith(isLoading: false, error: 'Please fill in all fields');
      return;
    }
    if (!_isValidUsername(u)) {
      state = state.copyWith(isLoading: false, error: 'Username may only contain letters, numbers, _ and . (1–30 chars)');
      return;
    }
    if (password.length < 8) {
      state = state.copyWith(isLoading: false, error: 'Password must be at least 8 characters');
      return;
    }
    try {
      final taken = await ref.read(firestoreServiceProvider).isUsernameTaken(u);
      if (taken) {
        state = state.copyWith(isLoading: false, error: 'That username is already taken');
        return;
      }
      final credential = await fb.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email.trim(), password: password);
      final newUser = UserModel(
        id: credential.user!.uid,
        username: u,
        displayName: u,
        bio: 'Explorer in the making',
      );
      await ref.read(firestoreServiceProvider).insertUser(newUser);
      state = state.copyWith(isLoading: false, user: newUser, isInitializing: false);
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong. Please try again.');
    }
  }

  // ── Google ─────────────────────────────────────────────────────────────────

  Future<void> loginWithGoogle() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // User cancelled the picker.
        state = state.copyWith(isLoading: false);
        return;
      }
      final googleAuth = await googleUser.authentication;
      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final result =
          await fb.FirebaseAuth.instance.signInWithCredential(credential);
      await _ensureUserProfile(result.user!);
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Google sign-in failed. Please try again.');
    }
  }

  // ── Phone / OTP ────────────────────────────────────────────────────────────

  /// Step 1: send OTP to [phone] (e.g. "+15551234567").
  Future<void> requestPhoneOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true, isLinkingPhone: false);
    await fb.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone.trim(),
      verificationCompleted: (credential) async {
        // Auto-verified on Android — sign in immediately.
        final result =
            await fb.FirebaseAuth.instance.signInWithCredential(credential);
        await _ensureUserProfile(result.user!);
      },
      verificationFailed: (e) {
        state = state.copyWith(isLoading: false, error: _authError(e.code));
      },
      codeSent: (verificationId, _) {
        state = state.copyWith(
          isLoading: false,
          phoneVerificationId: verificationId,
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Step 2: verify the 6-digit code the user typed.
  Future<void> verifyPhoneOtp(String smsCode) async {
    final verificationId = state.phoneVerificationId;
    if (verificationId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      final result =
          await fb.FirebaseAuth.instance.signInWithCredential(credential);
      await _ensureUserProfile(result.user!);
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
    }
  }

  // ── Account linking ────────────────────────────────────────────────────────

  /// Links an email/password credential to the current Firebase account.
  /// Same UID → same Firestore document, no duplicate user.
  Future<void> linkEmailPassword(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final credential =
          fb.EmailAuthProvider.credential(email: email.trim(), password: password);
      await fb.FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
      state = state.copyWith(isLoading: false);
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
    }
  }

  /// Step 1 for linking a phone to an existing account.
  Future<void> requestLinkPhoneOtp(String phone) async {
    state = state.copyWith(isLoading: true, clearError: true, isLinkingPhone: true);
    await fb.FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber: phone.trim(),
      verificationCompleted: (credential) async {
        await _linkCredential(credential);
      },
      verificationFailed: (e) {
        state = state.copyWith(isLoading: false, error: _authError(e.code));
      },
      codeSent: (verificationId, _) {
        state = state.copyWith(
          isLoading: false,
          phoneVerificationId: verificationId,
          isLinkingPhone: true,
        );
      },
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  /// Step 2 for linking phone.
  Future<void> confirmLinkPhoneOtp(String smsCode) async {
    final verificationId = state.phoneVerificationId;
    if (verificationId == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final credential = fb.PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );
      await _linkCredential(credential);
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
    }
  }

  Future<void> _linkCredential(fb.AuthCredential credential) async {
    try {
      await fb.FirebaseAuth.instance.currentUser?.linkWithCredential(credential);
      state = state.copyWith(
        isLoading: false,
        clearVerificationId: true,
        isLinkingPhone: false,
      );
    } on fb.FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authError(e.code));
    }
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────

  /// Creates a Firestore profile if one doesn't exist yet (new Google/Phone user),
  /// then sets auth state to authenticated.
  Future<void> _ensureUserProfile(fb.User firebaseUser) async {
    final service = ref.read(firestoreServiceProvider);
    var user = await service.getUserById(firebaseUser.uid);
    if (user == null) {
      final displayName =
          firebaseUser.displayName ?? firebaseUser.phoneNumber ?? 'Explorer';
      final username = await _generateUniqueUsername(displayName, service);
      user = UserModel(
        id: firebaseUser.uid,
        username: username,
        displayName: displayName,
        bio: 'Explorer in the making',
      );
      await service.insertUser(user);
    }
    state = state.copyWith(
      isLoading: false,
      user: user,
      isInitializing: false,
      clearVerificationId: true,
    );
  }

  /// Generates a unique username by sanitising [displayName] and appending
  /// random digits until a free slot is found.
  Future<String> _generateUniqueUsername(String displayName, dynamic service) async {
    final base = displayName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]'), '')
        .replaceAll(RegExp(r'^[_]+|[_]+$'), '');
    final root = base.isEmpty ? 'explorer' : base.substring(0, base.length.clamp(0, 20));
    if (!await service.isUsernameTaken(root)) return root;
    final rng = Random();
    for (var i = 0; i < 20; i++) {
      final candidate = '${root}_${100 + rng.nextInt(9900)}';
      if (!await service.isUsernameTaken(candidate)) return candidate;
    }
    return '${root}_${rng.nextInt(999999)}';
  }

  static bool _isValidUsername(String u) {
    if (u.isEmpty || u.length > 30) return false;
    if (!RegExp(r'^[a-z0-9][a-z0-9_.]*$').hasMatch(u)) return false;
    if (u.contains('..')) return false;
    if (u.endsWith('.')) return false;
    return true;
  }

  Future<void> loginAsGuest() async {
    state = state.copyWith(isLoading: true);
    await Future.delayed(const Duration(milliseconds: 300));
    state = state.copyWith(isLoading: false, isGuest: true, isInitializing: false);
  }

  Future<void> refreshUser() async {
    final uid = fb.FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || state.isGuest) return;
    final user = await ref.read(firestoreServiceProvider).getUserById(uid);
    if (user != null) state = state.copyWith(user: user);
  }

  Future<void> logout() async {
    ref.read(interactionProvider.notifier).clear();
    ref.read(followProvider.notifier).clear();
    await GoogleSignIn().signOut().catchError((_) => null);
    await fb.FirebaseAuth.instance.signOut();
    state = const AuthState(isInitializing: false);
  }

  String _authError(String code) {
    switch (code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'email-already-in-use':
        return 'An account with this email already exists';
      case 'weak-password':
        return 'Password is too weak (min. 8 characters)';
      case 'invalid-email':
        return 'Invalid email address';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-verification-code':
        return 'Invalid code. Please check and try again.';
      case 'invalid-phone-number':
        return 'Invalid phone number. Include country code (e.g. +1).';
      case 'provider-already-linked':
        return 'This account is already linked.';
      case 'credential-already-in-use':
        return 'This phone/email is linked to another account.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}

final authProvider =
    NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
