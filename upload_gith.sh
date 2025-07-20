#!/bin/bash

# Script to safely add, commit, and push all files to GitHub (branch: main)

# Check for uncommitted changes
if git diff-index --quiet HEAD --; then
    echo "No changes to commit."
else
    echo "Adding all changes..."
    git add .

    # Commit with user input message or default
    read -p "Enter commit message (or leave blank for default): " msg
    if [ -z "$msg" ]; then
        msg="Update files"
    fi

    git commit -m "$msg"
fi

echo "Pulling latest changes from origin/main to avoid conflicts..."
git pull origin main --rebase

echo "Pushing to origin main..."
git push origin main

echo "Done."
