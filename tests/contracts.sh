#!/usr/bin/env bash
set -euo pipefail

root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
export GITHUB_OUTPUT=$work/output

fail() {
  printf '%s\n' "$1" >&2
  exit 1
}

# Runs app-inputs.sh with the given variables, and keeps its exit code, messages and outputs.
read_app_inputs() {
  : >"$GITHUB_OUTPUT"
  status=0
  output=$(env -u TOOLCONFIG_CLIENT_ID -u TOOLCONFIG_PRIVATE_KEY_SET -u TOOLCONFIG_REPOSITORIES \
    "$@" bash "$root/app-inputs.sh" 2>&1) || status=$?
  outputs=$(<"$GITHUB_OUTPUT")
}

app=(TOOLCONFIG_CLIENT_ID=Iv23test TOOLCONFIG_PRIVATE_KEY_SET=true)

read_app_inputs TOOLCONFIG_PRIVATE_KEY_SET=false
[[ $status == 0 && $outputs == private=false ]] || fail 'No GitHub App inputs did not select the public path.'

read_app_inputs "${app[@]}" TOOLCONFIG_REPOSITORIES=$'  acme/policy \r\n\n\tacme/presets.test\t'
[[ $status == 0 ]] || fail "The GitHub App inputs failed: $output"
[[ $outputs == $'private=true\nowner=acme\nnames=policy,presets.test' ]] ||
  fail "The GitHub App inputs gave the wrong outputs: $outputs"
printf 'PASS public and private paths\n'

for partial in TOOLCONFIG_CLIENT_ID=Iv23test TOOLCONFIG_PRIVATE_KEY_SET=true TOOLCONFIG_REPOSITORIES=acme/policy; do
  read_app_inputs "$partial"
  [[ $status == 1 && $output == *'Give client-id, private-key and repositories together'* ]] ||
    fail "Only $partial did not fail."
done
read_app_inputs "${app[@]}" TOOLCONFIG_REPOSITORIES=$' \n\t'
[[ $status == 1 ]] || fail 'Blank repositories did not fail.'
read_app_inputs "${app[@]}" TOOLCONFIG_REPOSITORIES=missing-slash
[[ $status == 1 && $output == *"Invalid repository name 'missing-slash'."* ]] || fail 'An invalid name did not fail.'
read_app_inputs "${app[@]}" TOOLCONFIG_REPOSITORIES=$'acme/policy\nother/presets'
[[ $status == 1 && $output == *'more than one owner: acme and other.'* ]] || fail 'Two owners did not fail.'
printf 'PASS invalid GitHub App inputs\n'

# A ToolConfig that fails when it can read a credential, or cannot read what the scoped Git
# credential helper needs.
mkdir "$work/bin" "$work/project"
cat >"$work/bin/toolconfig" <<'TOOLCONFIG'
#!/usr/bin/env bash
for name in GITHUB_TOKEN GH_TOKEN ACTIONS_ID_TOKEN_REQUEST_URL AWS_ACCESS_KEY_ID \
  AWS_SECRET_ACCESS_KEY RR_S3_SESSION_TOKEN NPM_PASSWORD SSH_PRIVATE_KEY OPENAI_API_KEY; do
  [[ -z ${!name+set} ]] || { echo "ToolConfig can read $name." >&2; exit 1; }
done
[[ $SCOPED_GIT_TOKEN == test-token && $GIT_CONFIG_KEY_0 == test.key ]] ||
  { echo 'ToolConfig cannot read the scoped Git config.' >&2; exit 1; }
TOOLCONFIG
chmod +x "$work/bin/toolconfig"
git -C "$work/project" init -q
(
  cd "$work/project"
  export PATH=$work/bin:$PATH SCOPED_GIT_TOKEN=test-token GIT_CONFIG_KEY_0=test.key
  export GITHUB_TOKEN=x GH_TOKEN=x ACTIONS_ID_TOKEN_REQUEST_URL=x AWS_ACCESS_KEY_ID=x
  export AWS_SECRET_ACCESS_KEY=x RR_S3_SESSION_TOKEN=x NPM_PASSWORD=x SSH_PRIVATE_KEY=x OPENAI_API_KEY=x
  bash "$root/toolconfig.sh" >/dev/null
)
printf 'PASS ToolConfig environment\n'
