# Test Documentation — Motive Me

This document links every test script to the implemented app features it covers.

---

## Test Summary

| Type | Files | Tests | Status |
|---|---|---|---|
| Unit | 8 files | 76 tests | ✅ All pass |
| Widget | 2 files | 22 tests | ✅ All pass |
| Integration | 1 file | 11 tests | ✅ Requires device + Firebase |
| **Total** | **11 files** | **109 tests** | |

Run unit + widget tests:
```bash
flutter test test/unit/ test/widget/
```

Run integration tests (real device required):
```bash
flutter test integration_test/app_test.dart
```

---

## Unit Tests

Unit tests cover isolated business logic with no Flutter framework or Firebase dependencies.

### 1. `test/unit/models/activity_model_test.dart`

**Feature covered:** Activity data model (R2 — Skill/Activity Management)

| Test | What it verifies |
|---|---|
| `toMap() includes id, name and reward` | Activity serializes all fields correctly |
| `fromMap() parses all fields correctly` | Activity deserializes from Firebase map |
| `fromMap() uses default reward when missing` | Safe defaults on incomplete data |
| `round-trip toMap → fromMap preserves all data` | Serialization is lossless |

---

### 2. `test/unit/models/user_activity_model_test.dart`

**Feature covered:** User skill tracking — progress, expiry, check-in logic (R2, R3 — Check-in System)

| Test | What it verifies |
|---|---|
| `isExpired false when expiry is in the future` | Active skill detection |
| `isExpired true when expiry is in the past` | Expired skill detection |
| `isCompleted false when count < goal` | Incomplete skill detection |
| `isCompleted true when count == goal` | Completion detection |
| `hasCheckedInToday false when no check-ins` | First check-in allowed |
| `hasCheckedInToday true when today's timestamp exists` | Duplicate check-in blocked |
| `canCheckIn false when expired` | Cannot check in after deadline |
| `canCheckIn false when completed` | Cannot over-check-in |
| `canCheckIn false when already checked in today` | One check-in per day enforced |
| `canCheckIn true when active and not checked in today` | Normal check-in allowed |
| `progress is 0.0 when count is 0` | Progress bar starts at 0 |
| `progress is 1.0 when completed` | Progress bar fills on completion |
| `fromMap() parses checkInDates from List` | Firebase List format parsed |
| `fromMap() parses checkInDates from Map` | Firebase Map format parsed |
| `toMap() omits checkInDates when empty` | No unnecessary data stored |
| `round-trip preserves all fields` | Serialization is lossless |

---

### 3. `test/unit/models/user_model_test.dart`

**Feature covered:** User profile model (R1 — User Authentication & Profile)

| Test | What it verifies |
|---|---|
| `toMap() returns all fields except uid` | Profile serializes for Firebase |
| `fromMap() parses all fields correctly` | Profile deserializes from Firebase |
| `fromMap() uses default values for optional fields` | Handles incomplete profiles |
| `round-trip toMap → fromMap preserves all data` | Serialization is lossless |
| `uid is not included in toMap output` | uid not duplicated in Firebase node |

---

### 4. `test/unit/models/achievement_model_test.dart`

**Feature covered:** Achievement model (R4 — Achievements System)

| Test | What it verifies |
|---|---|
| `toMap() includes all fields except id` | Achievement serializes correctly |
| `fromMap() parses all fields correctly` | Achievement deserializes correctly |
| `fromMap() uses default values for missing fields` | Safe defaults |
| `round-trip preserves all data` | Serialization is lossless |

---

### 5. `test/unit/local/user_local_test.dart`

**Feature covered:** Local user data persistence — used for offline mode (R5 — Offline Support)

| Test | What it verifies |
|---|---|
| `saveUser() persists all fields to SharedPreferences` | User data stored locally |
| `getUserInfo() returns null when nothing saved` | Clean state handled |
| `getUserInfo() returns saved user` | User loaded from local storage |
| `getUserInfo() returns null when uid is missing` | Corrupt data handled safely |
| `clearUser() removes all user keys` | Logout clears local data |
| `round-trip save → load preserves all fields` | Local storage is lossless |

---

### 6. `test/unit/local/skill_entries_local_test.dart`

**Feature covered:** Offline skill cache — shows skills without internet (R5 — Offline Support)

| Test | What it verifies |
|---|---|
| `load() returns empty list when nothing saved` | Fresh install handled |
| `save() then load() preserves userActivity fields` | UserActivity cached correctly |
| `save() then load() preserves activity fields` | Activity cached correctly |
| `save() with empty list clears previous entries` | Cache replaced on update |
| `load() handles multiple entries` | Multiple skills cached |
| `clear() removes cached entries` | Cache can be wiped |
| `load() correctly parses checkInDates` | Check-in history preserved offline |
| `save() overwrites previous cache` | Cache always up to date |

---

### 7. `test/unit/local/achievement_local_test.dart`

**Feature covered:** Achievement persistence — locally tracked unlocked badges (R4 — Achievements)

| Test | What it verifies |
|---|---|
| `getUnlockedAchievementIds() returns empty set initially` | No achievements on fresh install |
| `saveUnlockedAchievementId() persists an id` | Achievement unlock saved |
| `saveUnlockedAchievementId() accumulates multiple ids` | Multiple achievements tracked |
| `getUnlockedAchievementIds() handles corrupt data` | Corrupt storage handled gracefully |
| `clearAchievements() removes all unlocked ids` | Achievements can be reset |

---

### 8. `test/unit/services/network_service_test.dart`

**Feature covered:** Internet connectivity check — gates all Firebase operations (R5 — Offline Support)

| Test | What it verifies |
|---|---|
| `isConnected() returns true when wifi is available` | WiFi connection detected |
| `isConnected() returns true when mobile is available` | Mobile data detected |
| `isConnected() returns true when ethernet is available` | Ethernet detected |
| `isConnected() returns false when no connectivity` | Offline correctly detected |
| `isConnected() returns false when list is empty` | Edge case: no interfaces |
| `isConnected() returns true when multiple results include wifi` | Multiple interfaces handled |
| `isConnected() returns false when multiple results are all none` | All-none case handled |
| `checkOrThrow() completes without throwing when connected` | Online path: no exception |
| `checkOrThrow() throws Exception when not connected` | Offline path: exception thrown |
| `checkOrThrow() throws Exception when list is empty` | Edge case throws correctly |

---

## Widget Tests

Widget tests render real Flutter UI in a fake environment. Firebase and platform channels are mocked.

### 9. `test/widget/home_screen_test.dart`

**Feature covered:** Home screen — offline mode, skill display, check-in UI (R2, R3, R5)

| Group | Test | What it verifies |
|---|---|---|
| No user | `redirects to login screen` | Unauthenticated users sent to login |
| Offline – valid user | `shows loading indicator initially then resolves` | Loading state shown during async init |
| Offline – valid user | `shows offline banner` | Wifi-off icon + "You're offline" text shown |
| Offline – valid user | `shows welcome message with user name` | User name displayed from local cache |
| Offline – valid user | `shows stat cards` | Total Skills, Done This Month, Points shown |
| Offline – valid user | `shows empty-skills state when no cached skills` | "No skills yet" shown with no cache |
| Offline – valid user | `shows achievements section` | Achievements section always visible |
| AppBar | `shows app title` | "Motive Meeee" title visible |
| AppBar | `add-skill button navigates to /create-skill` | Add button routes to skill creation |
| AppBar | `profile button navigates to /profile` | Profile icon routes to profile |
| Cached skills offline | `renders the cached skill card` | Cached skill name visible offline |
| Cached skills offline | `check-in button shows "No Internet" label` | Button label changes when offline |
| Cached skills offline | `check-in button is disabled when offline` | onPressed is null offline |
| Cached skills offline | `wifi_off icon appears on check-in button` | Correct icon shown offline |

---

### 10. `test/widget/login_screen_test.dart`

**Feature covered:** Login screen UI (R1 — User Authentication)

| Test | What it verifies |
|---|---|
| `shows email and password fields` | Both input fields rendered |
| `shows login button` | Login button present |
| `shows Sign up link` | Navigation to signup available |
| `shows error when fields are empty` | Validation message on empty submit |
| `shows Motive Me title` | App branding visible |
| `shows psychology icon` | App logo visible |
| `does not navigate when fields are empty` | Stays on login screen on empty submit |

---

## Integration Tests

Integration tests run on a real device against the live Firebase project. They test the full end-to-end flow.

### 11. `integration_test/app_test.dart`

**Feature covered:** Full app flow — all features end-to-end (R1–R5)

| Group | Test | Feature |
|---|---|---|
| Splash screen | `shows app name and bolt icon on launch` | R1 — App startup splash |
| Splash screen | `redirects to login when no user is cached` | R1 — Auth gate |
| Login UI | `shows email and password fields` | R1 — Login form |
| Login UI | `shows login button` | R1 — Login form |
| Login UI | `tapping Sign up navigates to signup screen` | R1 — Signup navigation |
| Login UI | `shows error when submitting empty fields` | R1 — Input validation |
| **Real Firebase login** | `logs in with valid credentials and navigates to home` | **R1 — Firebase Auth** |
| Real Firebase login | `shows error for wrong password` | R1 — Auth error handling |
| Home (authenticated) | `shows home screen content after login` | R2, R4 — Home screen structure |
| Home (authenticated) | `add-skill button is present and tappable` | R2 — Skill creation entry |
| Home (offline cached) | `shows welcome message with cached user name` | R5 — Offline user display |
| Home (offline cached) | `shows cached skill card` | R5 — Offline skill cache |

---

## Feature → Test Mapping

| Requirement | Feature | Test Files |
|---|---|---|
| R1 | User registration & login (Firebase Auth) | `widget/login_screen_test.dart`, `integration_test/app_test.dart` |
| R1 | Local user persistence (offline profile) | `unit/local/user_local_test.dart` |
| R2 | Skill/activity data model | `unit/models/activity_model_test.dart`, `unit/models/user_activity_model_test.dart` |
| R2 | Home screen skill list | `widget/home_screen_test.dart` |
| R3 | Check-in logic (one per day, expiry, completion) | `unit/models/user_activity_model_test.dart` |
| R3 | Check-in UI (disabled offline) | `widget/home_screen_test.dart` |
| R4 | Achievement model | `unit/models/achievement_model_test.dart` |
| R4 | Achievement local persistence | `unit/local/achievement_local_test.dart` |
| R5 | Internet connectivity detection | `unit/services/network_service_test.dart` |
| R5 | Offline skill cache (SharedPreferences) | `unit/local/skill_entries_local_test.dart` |
| R5 | Offline UI (banner, disabled buttons) | `widget/home_screen_test.dart` |
