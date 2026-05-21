#!/usr/bin/env bash
# team-dashboard-writer.sh — writes sample state for testing the team dashboard
# Usage: ./scripts/team-dashboard-writer.sh

set -euo pipefail

STATE_DIR="$HOME/.config/team-dashboard"
STATE_FILE="$STATE_DIR/state.json"
mkdir -p "$STATE_DIR"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
FIVE_AGO=$(date -u -v-5M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "5 minutes ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$NOW")
ONE_AGO=$(date -u -v-1M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "1 minute ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$NOW")
TEN_AGO=$(date -u -v-10M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "10 minutes ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$NOW")
THIRTY_AGO=$(date -u -v-30M +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d "30 minutes ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$NOW")

TMP=$(mktemp)
cat > "$TMP" << EOF
{
  "version": $(date +%s),
  "updatedAt": "$NOW",
  "teams": [
    {
      "teamId": "platform",
      "name": "Platform Infra",
      "status": "healthy",
      "currentUpdate": "Deploying v2.4.1 to staging",
      "activityLog": [
        {"timestamp": "$THIRTY_AGO", "message": "Health check passed", "severity": "info"},
        {"timestamp": "$TEN_AGO", "message": "Started canary deploy", "severity": "info"},
        {"timestamp": "$FIVE_AGO", "message": "Canary at 10% traffic", "severity": "info"},
        {"timestamp": "$NOW", "message": "Promoting canary to full rollout", "severity": "info"}
      ],
      "lastUpdated": "$NOW"
    },
    {
      "teamId": "frontend",
      "name": "Frontend",
      "status": "degraded",
      "currentUpdate": "Investigating slow page loads on dashboard",
      "activityLog": [
        {"timestamp": "$THIRTY_AGO", "message": "P95 latency above threshold (800ms)", "severity": "warn"},
        {"timestamp": "$TEN_AGO", "message": "On-call paged", "severity": "info"},
        {"timestamp": "$FIVE_AGO", "message": "Identified slow DB query in metrics endpoint", "severity": "info"},
        {"timestamp": "$NOW", "message": "Testing query optimization in staging", "severity": "info"}
      ],
      "lastUpdated": "$NOW"
    },
    {
      "teamId": "data",
      "name": "Data Pipeline",
      "status": "down",
      "currentUpdate": "Kafka cluster unreachable — escalating to AWS",
      "activityLog": [
        {"timestamp": "$THIRTY_AGO", "message": "Connection refused to broker-0", "severity": "error"},
        {"timestamp": "$TEN_AGO", "message": "Auto-scaler triggered but instances not healthy", "severity": "warn"},
        {"timestamp": "$FIVE_AGO", "message": "Failover to DR cluster initiated", "severity": "error"},
        {"timestamp": "$NOW", "message": "AWS support ticket opened — P1", "severity": "error"}
      ],
      "lastUpdated": "$NOW"
    }
  ]
}
EOF

mv "$TMP" "$STATE_FILE"
echo "State written to $STATE_FILE"
echo "Run /team-dashboard in Pi to view"
