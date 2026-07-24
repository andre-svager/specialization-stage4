#!/bin/sh
set -e

AUTH_URL="http://auth-service.default.svc.cluster.local:8001"
FLAG_URL="http://flag-service.default.svc.cluster.local:8002"
TARGET_URL="http://target-service.default.svc.cluster.local:8003"
EVAL_URL="http://evaluation-service.default.svc.cluster.local:8004"
ANALYTICS_URL="http://analytics-service.default.svc.cluster.local:8080"

MASTER_KEY="admin-secreto-123"
FLAG_NAME="enable-new-dashboard"

pass() { echo "  [OK] $1"; }
fail() { echo "  [FAIL] $1"; exit 1; }
step()  { echo ""; echo "== $1 =="; }

step "1/5 auth-service: health check"
curl -sf "$AUTH_URL/health" > /dev/null && pass "auth-service healthy" || fail "auth-service /health unreachable"

step "1/5 auth-service: create API key"
CREATE_RESP=$(curl -sf -X POST "$AUTH_URL/admin/keys" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${MASTER_KEY}" \
  -d '{"name": "integration-test"}')
echo "  response: $CREATE_RESP"
API_KEY=$(echo "$CREATE_RESP" | sed -n 's/.*"key":"\([^"]*\)".*/\1/p')
if [ -z "$API_KEY" ]; then fail "could not extract API key from response"; fi
pass "created API key: ${API_KEY}"

step "1/5 auth-service: validate the key"
curl -sf "$AUTH_URL/validate" -H "Authorization: Bearer ${API_KEY}" > /dev/null && pass "key validated" || fail "key validation failed"

step "1/5 auth-service: reject a bad key (negative test)"
BAD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$AUTH_URL/validate" -H "Authorization: Bearer totally-fake-key")
if [ "$BAD_STATUS" = "401" ]; then pass "bad key correctly rejected (401)"; else fail "expected 401 for bad key, got $BAD_STATUS"; fi

step "2/5 flag-service: health check"
curl -sf "$FLAG_URL/health" > /dev/null && pass "flag-service healthy" || fail "flag-service /health unreachable"

step "2/5 flag-service: reject unauthenticated request"
NOAUTH_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FLAG_URL/flags")
if [ "$NOAUTH_STATUS" = "401" ]; then pass "unauthenticated request correctly rejected (401)"; else echo "  [WARN] expected 401, got $NOAUTH_STATUS"; fi

step "2/5 flag-service: create flag '${FLAG_NAME}'"
curl -sf -X POST "$FLAG_URL/flags" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d "{\"name\": \"${FLAG_NAME}\", \"description\": \"integration test flag\", \"is_enabled\": true}" \
  > /dev/null && pass "flag created" || echo "  [WARN] flag creation failed (may already exist, continuing)"

step "2/5 flag-service: list flags"
curl -sf "$FLAG_URL/flags" -H "Authorization: Bearer ${API_KEY}" && echo "" && pass "flags listed" || fail "could not list flags"

step "3/5 target-service: health check"
curl -sf "$TARGET_URL/health" > /dev/null && pass "target-service healthy" || fail "target-service /health unreachable"

step "3/5 target-service: create targeting rule for '${FLAG_NAME}'"
curl -sf -X POST "$TARGET_URL/rules" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${API_KEY}" \
  -d "{\"flag_name\": \"${FLAG_NAME}\", \"is_enabled\": true, \"rules\": {\"type\": \"PERCENTAGE\", \"value\": 50}}" \
  > /dev/null && pass "targeting rule created" || echo "  [WARN] rule creation failed (may already exist, continuing)"

step "3/5 target-service: fetch the rule"
curl -sf "$TARGET_URL/rules/${FLAG_NAME}" -H "Authorization: Bearer ${API_KEY}" && echo "" && pass "rule fetched" || fail "could not fetch targeting rule"

step "4/5 evaluation-service: health check"
curl -sf "$EVAL_URL/health" > /dev/null && pass "evaluation-service healthy" || fail "evaluation-service /health unreachable"

step "4/5 evaluation-service: evaluate flag for two users"
curl -sf "${EVAL_URL}/evaluate?user_id=test-user-1&flag_name=${FLAG_NAME}" && echo "" && pass "evaluated for test-user-1" || fail "evaluation failed for test-user-1"
curl -sf "${EVAL_URL}/evaluate?user_id=test-user-2&flag_name=${FLAG_NAME}" && echo "" && pass "evaluated for test-user-2" || fail "evaluation failed for test-user-2"

step "5/5 analytics-service: health check"
curl -sf "$ANALYTICS_URL/health" > /dev/null && pass "analytics-service healthy" || fail "analytics-service /health unreachable"

echo ""
echo "== analytics-service is async - check separately =="
echo "kubectl logs -n default -l app.kubernetes.io/name=analytics-service --tail=20"
echo ""
echo "=========================================="
echo "Integration test complete"
echo "=========================================="
