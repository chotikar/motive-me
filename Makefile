# ── MotiveMe Test Scripts ─────────────────────────────────────────────────────
# Thin wrappers around scripts/test.sh — run `make list` to see all targets.

SCRIPT := ./scripts/test.sh

.PHONY: \
  test test-unit test-unit-models test-unit-local test-unit-services \
  test-widget test-integration test-coverage clean-coverage list \
  test-achievement-model test-activity-model test-user-activity-model test-user-model \
  test-achievement-local test-skill-local test-user-local \
  test-network test-database \
  test-firebase-achievements test-firebase-activity test-firebase-skill test-firebase-profile \
  test-login test-signup test-home test-create-skill test-edit-profile test-profile

# ── Suites ────────────────────────────────────────────────────────────────────

test:
	$(SCRIPT) all

test-unit:
	$(SCRIPT) unit

test-unit-models:
	$(SCRIPT) unit:models

test-unit-local:
	$(SCRIPT) unit:local

test-unit-services:
	$(SCRIPT) unit:services

test-widget:
	$(SCRIPT) widget

test-integration:
	$(SCRIPT) integration

test-integration-web:
	$(SCRIPT) integration:web

test-coverage:
	$(SCRIPT) coverage

clean-coverage:
	rm -rf coverage/

# ── Models ────────────────────────────────────────────────────────────────────

test-achievement-model:
	$(SCRIPT) feature:achievement-model

test-activity-model:
	$(SCRIPT) feature:activity-model

test-user-activity-model:
	$(SCRIPT) feature:user-activity-model

test-user-model:
	$(SCRIPT) feature:user-model

# ── Local Storage ─────────────────────────────────────────────────────────────

test-achievement-local:
	$(SCRIPT) feature:achievement-local

test-skill-local:
	$(SCRIPT) feature:skill-local

test-user-local:
	$(SCRIPT) feature:user-local

# ── Services ──────────────────────────────────────────────────────────────────

test-network:
	$(SCRIPT) feature:network

test-database:
	$(SCRIPT) feature:database

test-firebase-achievements:
	$(SCRIPT) feature:firebase-achievements

test-firebase-activity:
	$(SCRIPT) feature:firebase-activity

test-firebase-skill:
	$(SCRIPT) feature:firebase-skill

test-firebase-profile:
	$(SCRIPT) feature:firebase-profile

# ── Screens ───────────────────────────────────────────────────────────────────

test-login:
	$(SCRIPT) feature:login

test-signup:
	$(SCRIPT) feature:signup

test-home:
	$(SCRIPT) feature:home

test-create-skill:
	$(SCRIPT) feature:create-skill

test-edit-profile:
	$(SCRIPT) feature:edit-profile

test-profile:
	$(SCRIPT) feature:profile

# ── Help ──────────────────────────────────────────────────────────────────────

list:
	$(SCRIPT) list
