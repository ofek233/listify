import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Stream of auth changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Update user profile
    await userCredential.user?.updateDisplayName(displayName);
    await userCredential.user?.reload();

    // Save user to Firestore
    await _saveUserToFirestore(userCredential.user!);

    return userCredential;
  }

  // Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign in with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web: Use Firebase popup
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final userCredential = await _firebaseAuth.signInWithPopup(googleProvider);
        if (userCredential.user != null) {
          await _saveUserToFirestore(userCredential.user!);
        }
        return userCredential;
      } else {
        // Desktop and mobile: Google Sign-in not supported, use email/password
        throw Exception('Google Sign-in is only available on web. Please use email/password sign-in instead.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Save user to Firestore
  Future<void> _saveUserToFirestore(User user) async {
    final userDoc = _firestore.collection('users').doc(user.uid);
    final snapshot = await userDoc.get();

    if (!snapshot.exists) {
      await userDoc.set({
        'email': user.email,
        'displayName': user.displayName ?? 'User',
        'photoUrl': user.photoURL,
        'createdAt': DateTime.now().toIso8601String(),
      });
    }
  }

  // Get user data from Firestore
  Future<AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return AppUser.fromMap(doc.data() as Map<String, dynamic>, uid);
      }
    } catch (e) {
      debugPrint('Error getting user data: $e');
    }
    return null;
  }

  // Get user by email
  Future<AppUser?> getUserByEmail(String email) async {
    try {
      debugPrint('Searching for user with email: $email');
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      debugPrint('Query returned ${query.docs.length} documents');
      
      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        debugPrint('Found user: ${doc.data()}');
        return AppUser.fromMap(doc.data(), doc.id);
      } else {
        debugPrint('No user found with email: $email');
      }
    } catch (e) {
      debugPrint('Error getting user by email: $e');
    }
    return null;
  }

  // Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> signUp(String email, String password, String fullName) async {
    try {
      UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Save user data to Firestore
      await _firestore.collection('users').doc(userCredential.user!.uid).set({
        'uid': userCredential.user!.uid,
        'email': email,
        'fullName': fullName,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      rethrow;
    }
  }
}
