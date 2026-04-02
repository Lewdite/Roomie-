# Roomie

An iOS app for shared living — track expenses, coordinate chores, and communicate with housemates.

## Features

- **Expenses** — Track monthly household charges with receipt image upload (OCR auto-fills amounts). See who paid what, split costs, and mark settlements.
- **Chores** — Propose chores that require unanimous approval from all housemates. Once active, chores are assigned probabilistically using a fairness-weighted algorithm that balances the load over time. Completions are reflected on the weekly schedule.
- **Bulletin Board** — Post updates, pin important messages, and mark urgent notices that push-notify housemates.
- **Household** — Create or join a household with a 6-character invite code. Google and Apple sign-in.

## Tech Stack

| Layer | Choice |
|---|---|
| UI | SwiftUI (iOS 17+) |
| Auth | Firebase Auth (Google + Apple) |
| Database | Cloud Firestore |
| Storage | Firebase Storage (receipts, 60-day TTL) |
| Push | Firebase Cloud Messaging |
| OCR | Apple Vision framework (on-device) |

## Project Setup

### Prerequisites

- Xcode 15+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- A Firebase project

### Steps

1. **Clone the repo**
   ```bash
   git clone <repo-url>
   cd Roomie-
   ```

2. **Create Firebase project**
   - Go to [Firebase Console](https://console.firebase.google.com)
   - Create a new project
   - Add an iOS app with bundle ID `com.roomie.app`
   - Download `GoogleService-Info.plist` and place it at `Roomie/Resources/GoogleService-Info.plist`
   - Enable **Authentication** → Sign-in methods → Google, Apple
   - Enable **Cloud Firestore** (start in test mode, then apply rules below)
   - Enable **Firebase Storage**
   - Enable **Cloud Messaging**

3. **Generate the Xcode project**
   ```bash
   xcodegen generate
   ```

4. **Open and configure**
   ```bash
   open Roomie.xcodeproj
   ```
   - Set your Apple Developer Team in Signing & Capabilities
   - Add the `REVERSED_CLIENT_ID` from your `GoogleService-Info.plist` as a URL scheme in the target's Info tab

5. **Build and run** on a device or simulator (iOS 17+)

---

## Firestore Data Model

```
/users/{userId}
  displayName, email, photoURL, householdIds[], createdAt

/households/{householdId}
  name, memberIds[], adminId, inviteCode, createdAt

/households/{householdId}/expenses/{expenseId}
  title, amount, paidBy, splitAmong[], category, isRecurring,
  recurrenceFrequency, imageURL, imageExpiresAt, month ("YYYY-MM"),
  settlements[], createdBy, createdAt

/households/{householdId}/chores/{choreId}
  title, description, frequency, assignablePool[], approvals{},
  status, nextDueDate, currentAssigneeId, lastAssignedTo,
  completionCounts{}, createdBy, createdAt

/households/{householdId}/chores/{choreId}/completions/{completionId}
  choreId, completedBy, completedAt, weekOf

/households/{householdId}/bulletins/{bulletinId}
  title, content, authorId, isPinned, isUrgent, createdAt, updatedAt
```

## Firestore Security Rules

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() { return request.auth != null; }
    function isHouseholdMember(householdId) {
      return isSignedIn() &&
        request.auth.uid in get(/databases/$(database)/documents/households/$(householdId)).data.memberIds;
    }

    match /users/{userId} {
      allow read: if isSignedIn();
      allow write: if request.auth.uid == userId;
    }

    match /households/{householdId} {
      allow read, write: if isHouseholdMember(householdId);

      match /expenses/{expenseId} {
        allow read, write: if isHouseholdMember(householdId);
      }
      match /chores/{choreId} {
        allow read, write: if isHouseholdMember(householdId);
        match /completions/{completionId} {
          allow read, write: if isHouseholdMember(householdId);
        }
      }
      match /bulletins/{bulletinId} {
        allow read, write: if isHouseholdMember(householdId);
      }
    }
  }
}
```

## Firebase Storage Rules

```
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /receipts/{householdId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

> For production, tighten storage rules to verify household membership.

## Chore Assignment Algorithm

Chores use fairness-weighted random selection. Each eligible member's weight is `1 / (completionCount + 1)`, so members who have completed the chore fewer times are proportionally more likely to be assigned next. The previous assignee is excluded from the next round to prevent consecutive assignments.

## V2 Roadmap

- [ ] Chore completion photo evidence + points system
- [ ] Leaderboard for chore completions
- [ ] Full OCR auto-parsing (line items, vendor, date)
- [ ] Monthly expense summary export (PDF)
- [ ] Recurring expense auto-generation
- [ ] In-app payment integration (Stripe / Apple Pay)
