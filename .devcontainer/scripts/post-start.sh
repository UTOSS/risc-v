#!/usr/bin/bash

set -euo pipefail

WORKSPACE="$1"

git config --global --add safe.directory "$WORKSPACE"
echo "✅ Added $WORKSPACE to git safe directories"

echo 'hi'

SOCK_PATH=$(ls /tmp/vscode-ssh-auth-*.sock 2>/dev/null | head -n1)
if [[ -n "$SOCK_PATH" ]]; then
  echo "export SSH_AUTH_SOCK=$SOCK_PATH" >> ~/.zshrc
  echo "export SSH_AUTH_SOCK=$SOCK_PATH" >> ~/.bashrc
  export SSH_AUTH_SOCK=$SOCK_PATH
  echo "✅ Mapped SSH_AUTH_SOCK"
else
  echo "⚠️  VS Code agent socket not found; leaving SSH_AUTH_SOCK unchanged"
fi
