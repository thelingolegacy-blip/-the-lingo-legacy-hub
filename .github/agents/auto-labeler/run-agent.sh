#!/usr/bin/env bash
set -euo pipefail

# Basic auto-labeler example script
# Inputs:
#   - mapping file path (default .github/label-mapping.yml)
#   - GITHUB_EVENT_PATH env var provided by Actions: path to the event payload

MAPPING_FILE="${1:-.github/label-mapping.yml}"
EVENT_FILE="${GITHUB_EVENT_PATH:-/github/workflow/event.json}"

if [ ! -f "$EVENT_FILE" ]; then
  echo "Event file not found: $EVENT_FILE"
  exit 0
fi

# Extract PR number and repo info
PR_NUMBER=$(jq -r .pull_request.number < "$EVENT_FILE")
REPO_FULL=$(jq -r .repository.full_name < "$EVENT_FILE")
OWNER=$(echo "$REPO_FULL" | cut -d/ -f1)
REPO=$(echo "$REPO_FULL" | cut -d/ -f2)

if [ "$PR_NUMBER" = "null" ] || [ -z "$PR_NUMBER" ]; then
  echo "No pull request number found in event payload; exiting."
  exit 0
fi

# Determine labels from changed files
FILES=$(jq -r '.pull_request|.changed_files' < "$EVENT_FILE" 2>/dev/null || true)
# Fallback: use the GitHub API to list changed files
if [ "$FILES" = "null" ] || [ -z "$FILES" ]; then
  FILE_LIST=$(curl -s -H "Authorization: token $GITHUB_TOKEN" "https://api.github.com/repos/$OWNER/$REPO/pulls/$PR_NUMBER/files" | jq -r '.[].filename')
else
  FILE_LIST=""
fi

# Simple mapping loader
get_labels_for_file() {
  local file="$1"
  # Iterate mapping entries
  jq -r --arg file "$file" '.routes[] | select(.pattern!=null) | select(test(.pattern) ; "i") | .labels[]?' "$MAPPING_FILE" 2>/dev/null || true
}

LABELS_TO_ADD=()
for f in $FILE_LIST; do
  mapfile -t labels < <(get_labels_for_file "$f")
  for l in "${labels[@]}"; do
    LABELS_TO_ADD+=("$l")
  done
done

# Deduplicate
if [ ${#LABELS_TO_ADD[@]} -eq 0 ]; then
  echo "No labels determined for PR #$PR_NUMBER"
  exit 0
fi
UNIQUE_LABELS=($(printf "%s\n" "${LABELS_TO_ADD[@]}" | awk '!seen[$0]++'))

# Apply labels via GitHub API
labels_json=$(printf '%s\n' "${UNIQUE_LABELS[@]}" | jq -R -s -c 'split("\n")[:-1]')

echo "Adding labels to $OWNER/$REPO PR #$PR_NUMBER: ${UNIQUE_LABELS[*]}"

curl -s -X POST -H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$OWNER/$REPO/issues/$PR_NUMBER/labels" \
  -d "$labels_json"

echo "Done"
