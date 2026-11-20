#!/usr/bin/env bash
set -euo pipefail

# Pkl in shared configuration can read the environment, and ToolConfig needs no credential except
# the scoped Git token.
while IFS= read -r name; do
  case $name in
  SCOPED_GIT_TOKEN) ;;
  *TOKEN* | *SECRET* | *PASSWORD* | *ACCESS_KEY* | *PRIVATE_KEY* | *API_KEY*) unset "$name" ;;
  esac
done < <(compgen -e)

if ! command -v toolconfig >/dev/null; then
  echo '::error::ToolConfig is not on PATH. Pin it in mise.toml, and run jdx/mise-action before this action.'
  exit 1
fi

toolconfig --version
# Check before generating, so that CI cannot repair a stale tracked file without a failure.
toolconfig check --strict
toolconfig generate --strict
if ! git diff --exit-code -- .editorconfig .toolconfig.lock; then
  echo '::error::toolconfig generate changed tracked files. Run it, and commit the result.'
  exit 1
fi
