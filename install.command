#!/bin/bash
# Double-click to install (macOS).
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
if ! command -v node >/dev/null; then
  echo "Install Node.js first (https://nodejs.org, the LTS button), then double-click this file again."
else
  npm install --omit=dev && node setup.js
fi
read -r -p "Press Enter to close"
