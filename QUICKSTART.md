# Quick Start Guide - Firebase & Collaboration

## What Was Added

Your Listify app now has complete user authentication and list collaboration features!

## ✅ New Features

### 1. **User Authentication**
- Sign up with email and password
- Sign in with email and password
- Sign in with Google account
- Secure session management

### 2. **List Collaboration**
- Share lists with other users via email
- Three permission levels: Viewer, Editor, Owner
- Manage collaborators
- Remove access from people

### 3. **Home Screen Updates**
- "My Lists" tab: Your personal lists
- "Shared" tab: Lists others shared with you
- Sign out button

## 🚀 Getting Started

### Step 1: Configure Firebase
1. Open [Firebase Console](https://console.firebase.google.com/)
2. Create a new project
3. Enable Email/Password authentication
4. Enable Google Sign-in
5. Create Firestore Database (Production mode)
6. Apply the security rules from `FIREBASE_SETUP.md`

### Step 2: Connect Your App
1. Download your `google-services.json` from Firebase (for Android)
2. Place it in `android/app/` directory
3. Or use `flutterfire configure` command

### Step 3: Run the App
```bash
flutter pub get
flutter run
```

## 📱 Using the App

### First Time
1. App shows Login page
2. Click "Sign Up" to create account
3. Or use "Sign up with Google"
4. After signup, you'll see home page with default lists

### Creating Lists
- Use "+" button on My Lists tab
- Create folders to organize
- Lists are stored locally on your device

### Sharing a List
1. Open any list you created
2. Tap menu (three dots)
3. Select "Share / Collaborate"
4. Enter colleague's email
5. Choose role (Viewer, Editor, or Owner)
6. Click Invite

### Viewing Shared Lists
1. Go to "Shared" tab
2. Lists shared with you appear here
3. Tap to open
4. Edit if you have Editor role

## 📁 File Structure

New files created:
```
lib/
├── services/
│   ├── auth_service.dart       ← Authentication
│   └── firestore_service.dart  ← Cloud storage
├── models/
│   └── user_model.dart         ← User & sharing models
├── pages/
│   ├── login_page.dart         ← Sign-in page
│   └── signup_page.dart        ← Sign-up page
└── widgets/
    └── share_list_dialog.dart  ← Share dialog
```

Modified files:
- `main.dart` - Added auth flow
- `home_page.dart` - Added tabs and shared lists
- `list_detail_page.dart` - Added share option

## 🔐 Permission Levels

### Viewer
- ✅ View list and items
- ❌ Cannot edit
- ❌ Cannot invite others

### Editor
- ✅ View list and items
- ✅ Edit items
- ❌ Cannot delete list
- ❌ Cannot invite others

### Owner
- ✅ Full control
- ✅ Invite collaborators
- ✅ Change roles
- ✅ Remove people

## 🌐 Data Storage

### Local (On Your Device)
- Your folders
- Your lists
- List items and details

### Cloud (Firestore)
- Your user profile
- Sharing permissions
- Collaborator information

### Hybrid Approach
- Fast access locally
- Collaboration via cloud
- Works offline for personal lists

## ⚙️ Configuration Files

### pubspec.yaml
Added dependencies:
- `firebase_core: ^4.3.0` - Firebase foundation
- `firebase_auth: ^6.1.3` - Authentication
- `cloud_firestore: ^6.1.1` - Cloud database
- `google_sign_in: ^7.2.0` - Google login

### Firebase Settings
- Authentication: Email/Password + Google
- Firestore Database: Production mode
- Security Rules: Custom rules (see FIREBASE_SETUP.md)

## 🐛 Troubleshooting

### "Not Authenticated" Error
- Make sure you're signed in
- Check internet connection
- Try signing out and in again

### Shared List Not Appearing
- Verify collaborator has signed up
- Check they're using correct email
- Restart app
- Check internet connection

### Google Sign-in Not Working
- Verify SHA-1 fingerprint in Firebase
- Check device has Google Play Services
- Clear app cache and retry

## 📚 Documentation

See full documentation:
- `FIREBASE_SETUP.md` - Complete Firebase setup guide
- `COLLABORATION_DETAILS.md` - Implementation details
- `README.md` - Original app documentation

## 🎯 Next Steps

### Immediate
1. Set up Firebase project
2. Test sign-up and sign-in
3. Test sharing with another user
4. Verify permissions work

### Soon
1. Test on multiple devices
2. Add profile picture display
3. Implement share notifications
4. Add view-only link sharing

### Future
1. Real-time list updates
2. Comments on items
3. Change history/version control
4. Advanced permissions

## 💡 Tips

### Best Practices
- Use descriptive list names
- Share with specific people (Viewer by default)
- Review collaborators regularly
- Use Owner role carefully

### Quick Sharing
1. Share → type email → select role → Invite
2. Collaborator sees list in "Shared" tab
3. They can start collaborating immediately

### Managing Collaborators
1. Open list → Menu → Share
2. Change roles anytime
3. Remove access instantly
4. Audit who has access

## 🆘 Getting Help

### Common Questions

**Q: How do I share with someone?**
A: Open list → Menu → Share → Enter email → Invite

**Q: Can I change permissions later?**
A: Yes! Open share dialog → Use dropdown to change role

**Q: What if I remove someone?**
A: They lose access immediately. List disappears from their Shared tab.

**Q: Can multiple people edit same list?**
A: Yes! If they have Editor or Owner role, they can all edit

**Q: Is my data safe?**
A: Yes! Firebase security rules protect your data. Only authorized people can access.

## 📞 Support

For issues:
1. Check `FIREBASE_SETUP.md` for setup problems
2. Check `COLLABORATION_DETAILS.md` for technical details
3. Review Firebase console for error logs
4. Check Flutter Firebase documentation

---

**Version**: 1.0 with Authentication & Collaboration
**Last Updated**: 2026-01-17
