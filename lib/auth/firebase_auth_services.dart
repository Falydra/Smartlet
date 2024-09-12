import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Sign up method using email and password
  Future<User?> signUpWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Provide more specific error handling
      if (e.code == 'email-already-in-use') {
        print('Email is already in use.');
      } else if (e.code == 'weak-password') {
        print('The password is too weak.');
      } else if (e.code == 'invalid-email') {
        print('The email is invalid.');
      } else {
        print('Error: ${e.message}');
      }
    } catch (e) {
      // General error handling
      print("Unexpected error during sign-up: $e");
    }
    return null;
  }

  // Sign in method using email and password
  Future<User?> signInWithEmailAndPassword(String email, String password) async {
    try {
      UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      // Provide more specific error handling
      if (e.code == 'user-not-found') {
        print('No user found with this email.');
      } else if (e.code == 'wrong-password') {
        print('Incorrect password.');
      } else if (e.code == 'invalid-email') {
        print('The email address is not valid.');
      } else {
        print('Error: ${e.message}');
      }
    } catch (e) {
      // General error handling
      print("Unexpected error during sign-in: $e");
    }
    return null;
  }

  // Optional: Sign out method
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      print("User signed out");
    } catch (e) {
      print("Error signing out: $e");
    }
  }
}
