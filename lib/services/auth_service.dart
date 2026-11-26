import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class AuthService {
  FirebaseAuth? get _auth =>
      Firebase.apps.isNotEmpty ? FirebaseAuth.instance : null;

  User? get currentUser => _auth?.currentUser;

  String? get currentUid => _auth?.currentUser?.uid;

  Future<User?> ensureSignedIn() async {
    final auth = _auth;
    if (auth == null) return null;

    if (auth.currentUser != null) {
      return auth.currentUser;
    }

    final credential = await auth.signInAnonymously();
    return credential.user;
  }
}