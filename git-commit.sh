#!/bin/bash

# Ensure the OpenAI API key is available
if [ -z "$OPENAI_API_KEY" ]; then
  printf "❌ OPENAI_API_KEY environment variable not set.\n"
  exit 1
fi

# Check current branch
printf "🔍 Current branch:\n"
BRANCH=$(git branch --show-current)
printf "%s\n\n" "$BRANCH"

# Show staged files
printf "📦 Staged changes:\n"
STAGED=$(git diff --name-only --cached)
if [ -z "$STAGED" ]; then
  printf "No staged changes.\n"
  printf "🧩 Do you want to stage all changes? (y/n): "
  read -r STAGE_CONFIRM
  if [[ "$STAGE_CONFIRM" =~ ^[Yy]$ ]]; then
    git add .
    STAGED=$(git diff --name-only --cached)
    printf "✅ Staged files:\n"
    printf "%s\n" "$STAGED"
  else
    printf "❌ No files staged. Exiting.\n"
    exit 0
  fi
else
  printf "%s\n" "$STAGED"
fi
printf "\n"

# Get staged diff (truncated to 50 lines, exclude binary files, limit context)
DIFF=$(git diff --cached --diff-filter=d --unified=0 --no-color -- . ':(exclude)*.pdf' ':(exclude)*.png' ':(exclude)*.jpg' ':(exclude)*.jpeg' ':(exclude)*.gif' ':(exclude)*.svg' | head -n 50)

if [ -z "$DIFF" ]; then
  printf "No text diff (binary files only).\n"
  DIFF="Only binary/image files added (no text changes)."
fi

printf "🧾 Staged diff (first 50 lines):\n"
printf "%s\n" "$DIFF"
printf "…\n\n"

# Show recent commits
printf "📜 Recent commit history:\n"
git --no-pager log --oneline -n 10
printf "\n"

# Create temporary files
PROMPT_FILE=$(mktemp)
JSON_FILE=$(mktemp)

# Create the prompt text
printf "You're an expert developer writing Conventional Commits.\n\n" > "$PROMPT_FILE"
printf "Given this staged git diff, suggest a commit message using the format:\n" >> "$PROMPT_FILE"
printf "type(scope): description\n\n" >> "$PROMPT_FILE"
printf "Optionally, include a short body if helpful.\n\n" >> "$PROMPT_FILE"
printf "Branch name: %s\n\n" "$BRANCH" >> "$PROMPT_FILE"
printf "Staged files:\n%s\n\n" "$STAGED" >> "$PROMPT_FILE"
printf "Diff:\n%s\n" "$DIFF" >> "$PROMPT_FILE"

# Encode the prompt file as a JSON string
ENCODED_PROMPT=$(jq -Rs . < "$PROMPT_FILE")

# Create the JSON payload file
printf "{\n" > "$JSON_FILE"
printf "  \"model\": \"gpt-4\",\n" >> "$JSON_FILE"
printf "  \"messages\": [\n" >> "$JSON_FILE"
printf "    {\n" >> "$JSON_FILE"
printf "      \"role\": \"user\",\n" >> "$JSON_FILE"
printf "      \"content\": %s\n" "$ENCODED_PROMPT" >> "$JSON_FILE"
printf "    }\n" >> "$JSON_FILE"
printf "  ],\n" >> "$JSON_FILE"
printf "  \"temperature\": 0.4\n" >> "$JSON_FILE"
printf "}\n" >> "$JSON_FILE"

# Make the API call
RESPONSE_FILE=$(mktemp)
curl -s https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d @"$JSON_FILE" > "$RESPONSE_FILE"

# Extract the commit message
COMMIT_MSG=$(jq -r '.choices[0].message.content' < "$RESPONSE_FILE" 2>/dev/null)

# Check if a valid response was returned
if [ -z "$COMMIT_MSG" ] || [ "$COMMIT_MSG" = "null" ]; then
  printf "❌ Failed to generate commit message.\n"
  printf "\n📄 API Response:\n"
  cat "$RESPONSE_FILE"
  printf "\n"
  # Clean up temporary files
  rm "$PROMPT_FILE"
  rm "$JSON_FILE"
  rm "$RESPONSE_FILE"
  exit 1
fi

# Clean up temporary files
rm "$PROMPT_FILE"
rm "$JSON_FILE"
rm "$RESPONSE_FILE"

# Display and confirm commit
printf "\n"
printf "📝 Suggested commit message:\n"
printf "%s\n" "$COMMIT_MSG"
printf "\n"

printf "💬 Do you want to use this message to commit? (y/n): "
read -r CONFIRM
if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
  printf "%s" "$COMMIT_MSG" | git commit -F -
  printf "✅ Committed with AI-generated message.\n"
else
  printf "❌ Commit cancelled.\n"
fi
