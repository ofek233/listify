# Collaboration & Sharing Implementation Details

## Architecture Overview

### Authentication Layer (`auth_service.dart`)
Handles all Firebase Authentication operations:
- Email/password sign-up and sign-in
- Google sign-in integration
- User profile management in Firestore
- Email lookup for sharing features

### Data Layer (`firestore_service.dart`)
Manages all Firestore operations:
- User folders and lists
- List sharing and permissions
- Collaborator management
- Real-time data access

### UI Layer
- **LoginPage**: Sign-in interface with email and Google options
- **SignUpPage**: Registration interface
- **HomePage**: Tab-based interface with My Lists and Shared tabs
- **ListDetailPage**: List view with share dialog
- **ShareListDialog**: Permission management and invite interface

## Key Components

### 1. Authentication Service
```dart
AuthService
├── signUpWithEmail()         // Create new account
├── signInWithEmail()         // Email login
├── signInWithGoogle()        // Google login
├── getUserByEmail()          // Find user for sharing
├── signOut()                 // Logout
└── _saveUserToFirestore()    // Create user profile
```

### 2. Firestore Service
```dart
FirestoreService
├── User Folders
│   ├── createFolder()
│   ├── getUserFolders()
│   ├── updateFolder()
│   └── deleteFolder()
├── User Lists
│   ├── createList()
│   ├── getUserLists()
│   ├── updateList()
│   └── deleteList()
└── Sharing
    ├── shareListWithUser()
    ├── getSharedListsForUser()
    ├── getListShares()
    ├── updateShareRole()
    ├── removeShare()
    └── getUserAccessToList()
```

### 3. Data Models
```dart
AppUser
├── uid: String
├── email: String
├── displayName: String
├── photoUrl: String?
└── createdAt: DateTime

ListShare
├── id: String
├── listId: String
├── sharedByUserId: String
├── sharedWithUserId: String
├── role: ShareRole (viewer|editor|owner)
└── sharedAt: DateTime

ShareRole (Enum)
├── viewer (read-only)
├── editor (read + edit)
└── owner (full control + sharing)
```

## Data Storage

### Local Storage (SQLite)
- User folders
- User lists
- List items
- Item fields and values
- Automatically initialized with default folders/lists

### Firestore Cloud Storage
- User profiles (authentication metadata)
- List shares (collaboration data)
- Sharing history

### Hybrid Approach
- **Local**: Personal data for fast access and offline capability
- **Cloud**: Sharing data for collaboration and cross-device sync

## Permission System

### Viewer Role
- Can view list and all items
- Cannot modify anything
- Cannot change permissions

### Editor Role
- Can view and edit list items
- Cannot delete the list
- Cannot invite other collaborators
- Cannot change other collaborators' roles

### Owner Role
- Can modify list (rename, delete)
- Can edit all items
- Can invite new collaborators
- Can manage existing collaborators (change roles, remove)
- Can accept removal from shared list

## Sharing Flow

### Step 1: Open Share Dialog
```
User opens list → Taps menu → Selects "Share / Collaborate"
```

### Step 2: Enter Collaborator
```
Type email → Select role → Click Invite
```

### Step 3: Backend Processing
```
Firestore queries users collection by email
    ↓
If user found, create share document
    ↓
Share document includes:
- listId (which list)
- ownerUserId (who owns it)
- sharedWithUserId (who it's shared with)
- role (permission level)
```

### Step 4: Collaborator Access
```
Collaborator logs in → Home page → Shared tab
Lists shared with them appear automatically
```

## UI Components

### ShareListDialog
Features:
- Permission level explanation box
- Email input field
- Role dropdown selector
- Invite button
- Error messages display
- List of current collaborators
- Ability to change roles (owner only)
- Ability to remove collaborators (owner only)

### Home Page Tabs
- **My Lists**: Lists from local database
- **Shared**: Lists fetched from Firestore shares collection
- Each list shows creation/modification time
- Lists show collaborator count (if shared)

## State Management

### Session State
```dart
FirebaseAuth.instance.authStateChanges()
  - Listens for auth state changes
  - Redirects to login if signed out
  - Loads home page if signed in
```

### Data State
```dart
_HomePageState
├── folders (from SQLite)
├── lists (from SQLite)
├── sharedLists (from Firestore)
└── _loadData() triggers refresh
```

## Error Handling

### Authentication Errors
- Invalid credentials
- User not found
- Email already in use
- Google sign-in cancelled
- Network errors

### Sharing Errors
- User not found by email
- Already shared with user
- Permission denied (not owner)
- Database errors

### UI Feedback
- Error messages displayed in red boxes
- Loading indicators during operations
- Success snackbars after actions
- Disabled buttons during async operations

## Security Considerations

### Firebase Security Rules
```
- Only authenticated users can access data
- Users can only modify their own data
- Shares respect ownership
- Only owners can manage shares
```

### Data Validation
- Email format validation
- User existence verification
- Role permission checks
- Ownership verification before sharing

### Best Practices
- Never store sensitive data in UI state
- Use Firebase rules as primary security
- Validate on both client and server
- Use HTTPS for all communications
- Implement proper error messages (no sensitive info leaks)

## Performance Optimizations

### Firestore Queries
```dart
// Indexed queries for better performance
where('sharedWithUserId', isEqualTo: userId)
where('listId', isEqualTo: listId)
limit(1)  // When only need first result
```

### Local Caching
- SQLite for instant local access
- Only fetch from Firestore when needed
- Cache share list queries in state

### Batch Operations
- Update multiple shares at once (future enhancement)
- Bulk remove shares (future enhancement)

## Future Enhancements

### 1. Real-time Sync
```dart
StreamBuilder for live updates
Firestore listeners for shared list changes
Real-time item updates across users
```

### 2. Share Invitations
```dart
Pending invitations
Accept/decline flow
Email notifications
```

### 3. Advanced Sharing
```dart
Public links
Access codes
Time-limited access
Bulk sharing
```

### 4. Notifications
```dart
Firebase Cloud Messaging
Share notifications
Update notifications
Comment notifications
```

### 5. Conflict Resolution
```dart
Automatic sync conflict handling
Version control for lists
Undo/redo functionality
Change history
```

## Testing Checklist

- [ ] Create account with email
- [ ] Create account with Google
- [ ] Sign in with credentials
- [ ] Sign in with Google
- [ ] Create folders and lists
- [ ] Share list with another user
- [ ] Verify shared list appears in Shared tab
- [ ] Edit item with Editor role
- [ ] Cannot edit with Viewer role
- [ ] Change collaborator role as Owner
- [ ] Remove collaborator as Owner
- [ ] Sign out and verify redirect to login
- [ ] Multiple concurrent shares
- [ ] Permission boundaries enforcement

## Troubleshooting

### Shared Lists Not Appearing
1. Verify user is logged in correctly
2. Check Firestore has share documents
3. Verify sharedWithUserId matches current user
4. Check Firestore rules allow read access
5. Restart app to refresh

### Cannot Share List
1. Verify collaborator email is correct
2. Check collaborator has created account
3. Verify you're the owner
4. Check internet connection
5. Check Firestore write permissions

### Google Sign-in Issues
1. Verify SHA-1 fingerprint added to Firebase
2. Check Firebase project configuration
3. Verify scopes are correct
4. Try clearing app cache and data
