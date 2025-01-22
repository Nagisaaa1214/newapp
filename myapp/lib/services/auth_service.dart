import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<Map<String, dynamic>> signInWithEmailPassword(
      String email, String password) async {
    try {
      // Fixed method name here
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      
      if (userCredential.user != null) {
        // Get user data from Firestore
        final userData = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (userData.exists) {
          return {
            'success': true,
            'user': UserModel.fromFirestore(
                userData.data() as Map<String, dynamic>, userCredential.user!.uid),
            'message': 'Login successful'
          };
        } else {
          return {
            'success': true,
            'user': UserModel(
              uid: userCredential.user!.uid,
              email: userCredential.user!.email ?? '',
            ),
            'message': 'Login successful'
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Login failed'
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'user-not-found':
          message = 'No user found with this email.';
          break;
        case 'wrong-password':
          message = 'Wrong password provided.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        default:
          message = 'An error occurred during login.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.'
      };
    }
  }

  Future<Map<String, dynamic>> registerWithEmailPassword(
      String email, String password, String name) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        // Store user data in Firestore
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'created_at': DateTime.now(),
        });

        return {
          'success': true,
          'user': UserModel(
            uid: userCredential.user!.uid,
            email: email,
            name: name,
          ),
          'message': 'Registration successful'
        };
      }

      return {
        'success': false,
        'message': 'Registration failed'
      };
    } on FirebaseAuthException catch (e) {
      String message;
      switch (e.code) {
        case 'weak-password':
          message = 'The password provided is too weak.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists for this email.';
          break;
        case 'invalid-email':
          message = 'The email address is invalid.';
          break;
        default:
          message = 'An error occurred during registration.';
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred. Please try again.'
      };
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}