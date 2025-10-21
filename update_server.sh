#!/bin/bash

set -e

# Colors for readability
info() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
success() { echo -e "\033[1;32m[SUCCESS]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

info "Updating server files..."

# Ensure we’re inside a git repository
if [ ! -d .git ]; then
  error "Not a git repository!"
  exit 0
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
CURRENT_COMMIT=$(git rev-parse HEAD)

info "Current branch: $CURRENT_BRANCH"
info "Saving current state: $CURRENT_COMMIT"

# Stash all uncommitted changes (tracked + untracked)
STASH_NAME="auto-update-$(date +%s)"
git stash push --include-untracked -m "$STASH_NAME" >/dev/null 2>&1 || true

# Fetch latest updates
info "Fetching latest changes..."
git fetch origin "$CURRENT_BRANCH"

# Attempt to pull and merge
info "Attempting git pull..."
if git pull --no-edit --no-rebase origin "$CURRENT_BRANCH"; then
  success "Pull and merge completed successfully."
else
  error "Merge conflict or error detected! Rolling back..."

  # Abort merge and restore previous commit
  git merge --abort 2>/dev/null || true
  git reset --hard "$CURRENT_COMMIT"

  # Restore stashed changes
  if git stash list | grep -q "$STASH_NAME"; then
    info "Restoring local changes..."
    git stash pop >/dev/null 2>&1 || true
  fi

  info "Repository restored to $CURRENT_COMMIT."
  exit 0
fi

# Restore stashed changes if pull succeeded
if git stash list | grep -q "$STASH_NAME"; then
  info "Reapplying local changes..."
  if git stash pop; then
    success "Local changes restored successfully."
  else
    error "Warning: conflicts occurred while restoring your local changes."
    error "Please review the files manually."
  fi
fi

success "Repository successfully updated and local changes preserved."
