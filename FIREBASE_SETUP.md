# Firebase Integration & Collaboration Setup Guide

## Overview
This document outlines the complete authentication and collaboration system that has been integrated into Listify.

## Features Implemented

### 1. **User Authentication**
- Email/Password Sign-up and Sign-in
- Google Sign-in Integration
- Session persistence with Firebase Authentication

### 2. **User Management**
- User profiles stored in Firestore
- Each user has their own collections for folders and lists
- User data includes: email, displayName, photoURL, createdAt timestamp

### 3. **List Collaboration & Sharing**
- Share lists with other users via email address
- Three permission levels:
  - **Viewer**: Can view list and items (read-only)
  - **Editor**: Can view and edit items
  - **Owner**: Full control including sharing and managing collaborators
- Share/Collaborator option accessible from list detail page menu

### 4. **Home Page Tabs**
- **My Lists**: Lists created by the current user (local database)
- **Shared**: Lists shared with the current user (from Firestore)
- Sign-out option in app bar

## File Structure

### New Files Created:
```
lib/
├── services/
│   ├── auth_service.dart         # Firebase authentication
│   └── firestore_service.dart    # Firestore operations
├── models/
│   └── user_model.dart           # AppUser, ShareRole, ListShare models
├── pages/
│   ├── login_page.dart           # Email/Google login
│   └── signup_page.dart          # Email/Google sign-up
└── widgets/
    └── share_list_dialog.dart    # Share dialog with permission management
```

### Modified Files:
- `lib/main.dart`: Added auth flow and routing
- `lib/pages/home_page.dart`: Added tabs and shared lists functionality
- `lib/pages/list_detail_page.dart`: Added share option to menu

## Firebase Setup Instructions

### 1. Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Click "Add project"
3. Follow the wizard and enable Google Analytics (optional)

### 2. Enable Authentication
1. In Firebase Console, go to **Authentication**
2. Click "Get started"
3. Enable **Email/Password** provider
4. Enable **Google** provider and configure OAuth:
   - Click on Google provider
   - Add your app's SHA-1 fingerprint (for Android)
   - Configure consent screen

### 3. Enable Firestore Database
1. Go to **Firestore Database**
2. Click "Create database"
3. Choose **Production mode** (or Start in test mode temporarily)
4. Select region (e.g., us-central1)

### 4. Set Firestore Security Rules
```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read, write: if request.auth.uid == userId;
      allow read: if exists(/databases/$(database)/documents/shares/$(request.auth.uid));
    }
    
    // Shares collection
    match /shares/{shareId} {
      allow read: if request.auth.uid == resource.data.sharedWithUserId || 
                     request.auth.uid == resource.data.sharedByUserId;
      allow create: if request.auth.uid == request.resource.data.sharedByUserId;
      allow update, delete: if request.auth.uid == resource.data.sharedByUserId;
    }
  }
}
```

### 5. Configure Google Sign-In
For Android:
1. Get your app's SHA-1 fingerprint:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
2. Add fingerprint to Firebase Console > Project Settings > Your apps

For iOS:
1. iOS setup happens automatically with `google_sign_in` package

## How to Use

### Sign Up
1. Launch app
2. Click "Sign Up" on login page
3. Enter name, email, password
4. Can also use "Sign up with Google"
5. App creates user profile in Firestore and local database

### Sign In
1. Enter credentials or use Google Sign-in
2. Default folders and lists load locally
3. Shared lists load from Firestore

### Create/Manage Lists
- **My Lists tab**: Create and manage personal lists
- Lists are stored in SQLite locally
- Create folders to organize lists

### Share a List
1. Open a list
2. Tap three dots menu
3. Select "Share / Collaborate"
4. Enter collaborator's email
5. Choose permission level (Viewer/Editor/Owner)
6. Click "Invite"

### View Shared Lists
1. Go to **Shared tab** on home page
2. Lists shared with you appear here
3. Tap to open and view based on your permission level
4. Edit items if you have Editor role
5. Manage collaborators if you have Owner role

### Manage Collaborators
- As Owner, open the share dialog
- Change roles using dropdown
- Remove collaborators with delete icon

## Data Flow

### Authentication Flow:
```
User (Sign Up) → Firebase Auth → User Profile Created in Firestore
                                → Local Database Initialized
                                → Home Page with tabs
```

### Sharing Flow:
```
Owner Opens Share Dialog
    ↓
Enters Collaborator Email
    ↓
Firebase queries Firestore for user by email
    ↓
Creates Share document in Firestore
    ↓
Collaborator sees list in "Shared" tab
    ↓
Collaborator can view/edit based on role
```

## Collections Structure

### users/
```
{uid}
├── email: string
├── displayName: string
├── photoUrl: string (optional)
└── createdAt: timestamp
```

### shares/
```
{shareId}
├── listId: string
├── sharedByUserId: string
├── sharedWithUserId: string
├── sharedWithEmail: string
├── role: string (viewer|editor|owner)
└── sharedAt: timestamp
```

## Firestore Rules Explanation

The rules ensure:
- Users can only read/write their own data
- Shared lists are accessible to authorized users only
- Only the owner can create/update/delete shares
- Email sharing is secure through UID verification

## Next Steps & Enhancements

1. **Send Invitations**: Add email notifications when lists are shared
2. **Accept/Decline Shares**: Let users manage share invitations
3. **Share Links**: Implement shareable links with access codes
4. **Sync Local Data**: Automatically sync local lists to Firestore
5. **Real-time Updates**: Use Firestore listeners for live collaboration
6. **Permissions UI**: Add more granular permission management
7. **Version History**: Track changes to shared lists
8. **Comments**: Add collaboration comments on list items

## Common Issues & Solutions

### Issue: Google Sign-in not working
**Solution**: Verify SHA-1 fingerprint is added to Firebase Console

### Issue: Shared lists not appearing
**Solution**: Check Firestore rules and ensure share document exists with correct userID

### Issue: Permission denied in Firestore
**Solution**: Verify user is authenticated and rules allow the operation

### Issue: Email not found when sharing
**Solution**: Ensure collaborator has created an account first

## Support
For Firebase documentation: https://firebase.google.com/docs
For Flutter Firebase docs: https://firebase.flutter.dev/
