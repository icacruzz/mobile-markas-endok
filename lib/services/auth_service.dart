import 'package:firebase_auth/firebase_auth.dart';

/// Service untuk mengelola autentikasi Firebase.
/// Single-user mode — hanya akun terdaftar yang bisa login.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// User saat ini (null jika belum login)
  User? get currentUser => _auth.currentUser;

  /// Stream perubahan status auth
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Login dengan email & password.
  /// Throw [FirebaseAuthException] jika gagal.
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Create an account for the first registered farm owner.
  Future<UserCredential> register({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  /// Logout user saat ini
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Mendapatkan pesan error yang user-friendly dari FirebaseAuthException
  static String getErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Akun tidak ditemukan. Periksa email Anda.';
      case 'wrong-password':
        return 'Password salah. Silakan coba lagi.';
      case 'invalid-email':
        return 'Format email tidak valid.';
      case 'user-disabled':
        return 'Akun ini telah dinonaktifkan.';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan. Coba lagi nanti.';
      case 'invalid-credential':
        return 'Email atau password salah.';
      case 'email-already-in-use':
        return 'Email sudah terdaftar. Silakan masuk.';
      case 'weak-password':
        return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
      default:
        return 'Terjadi kesalahan: ${e.message}';
    }
  }
}
