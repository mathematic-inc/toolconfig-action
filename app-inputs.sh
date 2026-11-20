#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf '::error::%s\n' "$1"
  exit 1
}

given=0
[[ -z ${TOOLCONFIG_CLIENT_ID:-} ]] || given=$((given + 1))
[[ ${TOOLCONFIG_PRIVATE_KEY_SET:-false} != true ]] || given=$((given + 1))
[[ ! ${TOOLCONFIG_REPOSITORIES:-} =~ [^[:space:]] ]] || given=$((given + 1))

case $given in
0)
  echo private=false >>"$GITHUB_OUTPUT"
  exit 0
  ;;
3) ;;
*) fail 'Give client-id, private-key and repositories together, or none of them.' ;;
esac

owner=
names=
while IFS= read -r repository; do
  repository=${repository#"${repository%%[![:space:]]*}"}
  repository=${repository%"${repository##*[![:space:]]}"}
  [[ -n $repository ]] || continue
  [[ $repository =~ ^([A-Za-z0-9_-]+)/([A-Za-z0-9_.-]+)$ ]] ||
    fail "Invalid repository name '${repository//[[:cntrl:]]/?}'. Use owner/name."
  # A GitHub App token is for the repositories of one owner.
  [[ -z $owner || ${BASH_REMATCH[1]} == "$owner" ]] ||
    fail "The repositories have more than one owner: $owner and ${BASH_REMATCH[1]}."
  owner=${BASH_REMATCH[1]}
  names+=${names:+,}${BASH_REMATCH[2]}
done <<<"$TOOLCONFIG_REPOSITORIES"

{
  echo private=true
  echo "owner=$owner"
  echo "names=$names"
} >>"$GITHUB_OUTPUT"
