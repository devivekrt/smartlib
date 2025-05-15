import 'package:firebase_auth/firebase_auth.dart';


Future<void> loginWithEmail(String email, String password) async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance
        .signInWithEmailAndPassword(email: email, password: password);
    print('User logged in: ${userCredential.user?.uid}');
  } on FirebaseAuthException catch (e) {
    print('Login error: ${e.message}');
  }
}


