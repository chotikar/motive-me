#!/bin/bash
# ── MotiveMe Test Runner ──────────────────────────────────────────────────────
# Usage:
#   ./scripts/test.sh                      all unit + widget tests
#   ./scripts/test.sh all                  same as above
#   ./scripts/test.sh unit                 all unit tests
#   ./scripts/test.sh unit:models          model serialisation tests
#   ./scripts/test.sh unit:local           local storage tests
#   ./scripts/test.sh unit:services        service & Firebase tests
#   ./scripts/test.sh widget               all widget / screen tests
#   ./scripts/test.sh feature:<name>       single-feature tests (see list below)
#   ./scripts/test.sh integration          integration tests (needs device)
#   ./scripts/test.sh coverage             all unit + widget tests + lcov report
#   ./scripts/test.sh list                 print all available feature targets

set -e

GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

run() {
  echo -e "${CYAN}▶ flutter test $*${NC}"
  flutter test "$@"
}

banner() {
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}${GREEN}  $1${NC}"
  echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# ── Feature targets (single file) ─────────────────────────────────────────────

feature_target() {
  case "$1" in

    # ── Models ────────────────────────────────────────────────────────────────

    achievement-model)
      banner "Feature: Achievement Model"
      run test/unit/models/achievement_model_test.dart
      ;;

    activity-model)
      banner "Feature: Activity Model"
      run test/unit/models/activity_model_test.dart
      ;;

    user-activity-model)
      banner "Feature: UserActivity Model"
      run test/unit/models/user_activity_model_test.dart
      ;;

    user-model)
      banner "Feature: User Model"
      run test/unit/models/user_model_test.dart
      ;;

    # ── Local Storage ─────────────────────────────────────────────────────────

    achievement-local)
      banner "Feature: Achievement Local Storage"
      run test/unit/local/achievement_local_test.dart
      ;;

    skill-local)
      banner "Feature: Skill Entries Local Storage"
      run test/unit/local/skill_entries_local_test.dart
      ;;

    user-local)
      banner "Feature: User Local Storage"
      run test/unit/local/user_local_test.dart
      ;;

    # ── Services ──────────────────────────────────────────────────────────────

    network)
      banner "Feature: Network Service"
      run test/unit/services/network_service_test.dart
      ;;

    database)
      banner "Feature: Database Service (App Startup)"
      run test/unit/services/database_service_test.dart
      ;;

    firebase-achievements)
      banner "Feature: Firebase Achievements Service"
      run test/unit/services/firebase_achievements_service_test.dart
      ;;

    firebase-activity)
      banner "Feature: Firebase Activity Service"
      run test/unit/services/firebase_activity_service_test.dart
      ;;

    firebase-skill)
      banner "Feature: Firebase Skill Service"
      run test/unit/services/firebase_skill_service_test.dart
      ;;

    firebase-profile)
      banner "Feature: Firebase User Profile Service"
      run test/unit/services/firebase_user_profile_service_test.dart
      ;;

    # ── Screens ───────────────────────────────────────────────────────────────

    login)
      banner "Feature: Login Screen"
      run test/widget/login_screen_test.dart
      ;;

    signup)
      banner "Feature: Signup Screen"
      run test/widget/signup_screen_test.dart
      ;;

    home)
      banner "Feature: Home Screen"
      run test/widget/home_screen_test.dart
      ;;

    create-skill)
      banner "Feature: Create Skill Screen"
      run test/widget/create_skill_screen_test.dart
      ;;

    edit-profile)
      banner "Feature: Edit Profile Screen"
      run test/widget/edit_profile_screen_test.dart
      ;;

    profile)
      banner "Feature: Profile Screen"
      run test/widget/profile_screen_test.dart
      ;;

    *)
      echo -e "${RED}Unknown feature: $1${NC}"
      echo "Run './scripts/test.sh list' to see all feature targets."
      exit 1
      ;;
  esac
}

# ── Main dispatch ─────────────────────────────────────────────────────────────

case "${1:-all}" in

  all)
    banner "All Unit + Widget Tests"
    run test/
    ;;

  unit)
    banner "All Unit Tests"
    run test/unit/
    ;;

  unit:models)
    banner "Unit Tests — Models"
    run \
      test/unit/models/achievement_model_test.dart \
      test/unit/models/activity_model_test.dart \
      test/unit/models/user_activity_model_test.dart \
      test/unit/models/user_model_test.dart
    ;;

  unit:local)
    banner "Unit Tests — Local Storage"
    run \
      test/unit/local/achievement_local_test.dart \
      test/unit/local/skill_entries_local_test.dart \
      test/unit/local/user_local_test.dart
    ;;

  unit:services)
    banner "Unit Tests — Services"
    run \
      test/unit/services/network_service_test.dart \
      test/unit/services/database_service_test.dart \
      test/unit/services/firebase_achievements_service_test.dart \
      test/unit/services/firebase_activity_service_test.dart \
      test/unit/services/firebase_skill_service_test.dart \
      test/unit/services/firebase_user_profile_service_test.dart
    ;;

  widget)
    banner "Widget Tests — All Screens"
    run \
      test/widget/login_screen_test.dart \
      test/widget/signup_screen_test.dart \
      test/widget/home_screen_test.dart \
      test/widget/create_skill_screen_test.dart \
      test/widget/edit_profile_screen_test.dart \
      test/widget/profile_screen_test.dart
    ;;

  feature:*)
    feature_target "${1#feature:}"
    ;;

  integration)
    banner "Integration Tests — Mobile (device/emulator required)"
    flutter test integration_test/app_test.dart "${@:2}"
    flutter test integration_test/app_bva_test.dart "${@:2}"
    flutter test integration_test/app_intregration_test.dart "${@:2}"
    ;;

  integration:web)
    banner "Integration Tests — Chrome (flutter drive)"
    # Ensure chromedriver is running on port 4444 before calling this.
    # Start it with: ./chromedriver-mac-arm64/chromedriver --port=4444 &
    flutter drive \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/app_test.dart \
      -d chrome "${@:2}"
    flutter drive \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/app_bva_test.dart \
      -d chrome "${@:2}"
    flutter drive \
      --driver=test_driver/integration_test.dart \
      --target=integration_test/app_intregration_test.dart \
      -d chrome "${@:2}"
    ;;

  coverage)
    banner "Tests + Coverage Report"
    run --coverage test/
    echo ""
    if command -v lcov &>/dev/null; then
      lcov --summary coverage/lcov.info
      echo ""
      echo -e "${CYAN}Full report: coverage/lcov.info${NC}"
    else
      echo -e "${YELLOW}Install lcov for a summary: brew install lcov${NC}"
      echo -e "${CYAN}Coverage written to: coverage/lcov.info${NC}"
    fi
    ;;

  list)
    echo ""
    echo -e "${BOLD}Available targets for ./scripts/test.sh${NC}"
    echo ""
    echo -e "${YELLOW}Top-level:${NC}"
    echo "  all                      All unit + widget tests"
    echo "  unit                     All unit tests"
    echo "  unit:models              Model serialisation tests"
    echo "  unit:local               Local storage tests"
    echo "  unit:services            Service + Firebase tests"
    echo "  widget                   All screen widget tests"
    echo "  integration              Integration tests (needs device)"
    echo "  coverage                 Tests + lcov coverage report"
    echo ""
    echo -e "${YELLOW}feature:<name> — single feature:${NC}"
    echo ""
    echo "  Models:"
    echo "    feature:achievement-model     Achievement serialisation/deserialisaton"
    echo "    feature:activity-model        Activity toMap/fromMap/copyWith"
    echo "    feature:user-activity-model   UserActivity computed props + check-in logic"
    echo "    feature:user-model            UserModel factory, copyWith, timestamps"
    echo ""
    echo "  Local Storage:"
    echo "    feature:achievement-local     Achievement unlock id persistence"
    echo "    feature:skill-local           Skill entries cache (load/save/clear)"
    echo "    feature:user-local            User profile cache (save/get/clear)"
    echo ""
    echo "  Services:"
    echo "    feature:network               Connectivity check + checkOrThrow"
    echo "    feature:database              App-start initialisation + offline fallback"
    echo "    feature:firebase-achievements Unlock, save, list achievements"
    echo "    feature:firebase-activity     Create, read, check-in, stream activities"
    echo "    feature:firebase-skill        Create skill + add from suggestion"
    echo "    feature:firebase-profile      Create, fetch, update user profile"
    echo ""
    echo "  Screens:"
    echo "    feature:login                 Login form, validation, auth flow"
    echo "    feature:signup                Signup form, 5-rule validation, auth flow"
    echo "    feature:home                  Home screen, stats, achievements, check-in"
    echo "    feature:create-skill          Create skill form, date picker, suggestion"
    echo "    feature:edit-profile          Edit profile, image picker, update flow"
    echo "    feature:profile               Profile display, logout, achievement count"
    echo ""
    ;;

  *)
    echo -e "${RED}Unknown target: $1${NC}"
    echo "Run './scripts/test.sh list' to see all targets."
    exit 1
    ;;
esac
