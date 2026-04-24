#!/usr/bin/env bash
# check-coverage.sh: Validates test coverage meets minimum thresholds
# and annotates the Buildkite build with coverage results.

set -euo pipefail

COVERAGE_FILE="${1:-coverage.out}"
MIN_COVERAGE="${MIN_COVERAGE_THRESHOLD:-80}"
COVERAGE_HTML="coverage.html"
COVERAGE_JSON="coverage.json"

if [[ ! -f "${COVERAGE_FILE}" ]]; then
  echo "--- :x: Coverage file not found: ${COVERAGE_FILE}"
  exit 1
fi

echo "--- :golang: Parsing coverage report"

# Extract total coverage percentage from go tool cover output
COVERAGE_OUTPUT=$(go tool cover -func="${COVERAGE_FILE}" | tail -1)
COVERAGE_PCT=$(echo "${COVERAGE_OUTPUT}" | awk '{print $3}' | tr -d '%')

echo "Total coverage: ${COVERAGE_PCT}%"

# Generate HTML report for artifact upload
go tool cover -html="${COVERAGE_FILE}" -o "${COVERAGE_HTML}"

# Write JSON summary for downstream steps
cat > "${COVERAGE_JSON}" <<EOF
{
  "total": ${COVERAGE_PCT},
  "threshold": ${MIN_COVERAGE},
  "passed": $(awk "BEGIN { print (${COVERAGE_PCT} >= ${MIN_COVERAGE}) ? \"true\" : \"false\" }")
}
EOF

# Determine pass/fail
if awk "BEGIN { exit !(${COVERAGE_PCT} >= ${MIN_COVERAGE}) }"; then
  STYLE="success"
  ICON=":white_check_mark:"
  STATUS="passed"
else
  STYLE="error"
  ICON=":x:"
  STATUS="failed"
fi

# Annotate the Buildkite build with coverage results
buildkite-agent annotate --style "${STYLE}" --context "coverage" <<EOF
### ${ICON} Test Coverage Report

| Metric | Value |
|--------|-------|
| **Total Coverage** | ${COVERAGE_PCT}% |
| **Minimum Threshold** | ${MIN_COVERAGE}% |
| **Status** | ${STATUS} |

> Coverage HTML report uploaded as a build artifact.
EOF

echo "--- :buildkite: Uploading coverage artifacts"
buildkite-agent artifact upload "${COVERAGE_HTML}"
buildkite-agent artifact upload "${COVERAGE_JSON}"

if [[ "${STATUS}" == "failed" ]]; then
  echo "Coverage ${COVERAGE_PCT}% is below the required threshold of ${MIN_COVERAGE}%"
  exit 1
fi

echo "Coverage check passed: ${COVERAGE_PCT}% >= ${MIN_COVERAGE}%"
