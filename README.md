# ToolConfig for GitHub Actions

`mathematic-inc/toolconfig-action` checks the files that
[ToolConfig](https://github.com/mathematic-inc/toolconfig) generates, then
generates them again. The step fails when a tracked file is not current, for
example an `.editorconfig` that is older than its source.

## Usage

The examples use the release `v2026.11.0`. Pin its full commit, with the version
in a comment.

Pin ToolConfig in `mise.toml`:

```toml
[tools]
"github:mathematic-inc/toolconfig" = "2026.11.4"
```

Then run mise before the action:

```yaml
permissions:
  contents: read

steps:
  - uses: actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1
    with:
      persist-credentials: false
  - uses: jdx/mise-action@90f833d396d0cc3674b631d2d225e306476c303a # v5.2.10
  # v2026.11.0
  - uses: mathematic-inc/toolconfig-action@1baf7b021e8bf6f0e20737753c13af0fc93c8570
```

For shared configuration in private repositories, give a GitHub App that can
read them:

```yaml
# v2026.11.0
- uses: mathematic-inc/toolconfig-action@1baf7b021e8bf6f0e20737753c13af0fc93c8570
  with:
    client-id: ${{ vars.TOOLCONFIG_APP_CLIENT_ID }}
    private-key: ${{ secrets.TOOLCONFIG_APP_PRIVATE_KEY }}
    repositories: my-org/toolconfig
```

## Commands

The action runs these commands in `working-directory`:

1. `toolconfig check --strict` fails when a tracked file is modified, stale or
   obsolete. It runs first, so CI cannot repair a stale file without a failure.
2. `toolconfig generate --strict` writes all the files again, the gitignored
   tool files too, for the steps that follow.
3. `git diff --exit-code -- .editorconfig .toolconfig.lock` fails when step 2
   changed a tracked file.

ToolConfig 2026.11.4 or later is necessary, because earlier releases keep their
records in `.toolconfig-state/state.json`, not in `.toolconfig.lock`.

## How the action gets ToolConfig

The action runs the `toolconfig` on `PATH` and does not install ToolConfig.
We chose this design for these reasons:

- The version has one pin, in `mise.toml`. Hooks, tasks and CI use the same
  version, and one change updates all of them.
- mise checks the archive against the SHA256 digest that GitHub gives for the
  release asset. When you commit `mise.lock`, mise also checks the archive
  against the SHA256 in that file.
- A `version` input that downloads a release and checks its SHA256 would do
  again what mise does.

Other installers are also satisfactory if they put `toolconfig` on `PATH`.

## Inputs

| Input | Default | Purpose |
| --- | --- | --- |
| `working-directory` | `.` | Directory of the root source (`root = true`). A relative path starts at `github.workspace`. |
| `client-id` | None | Client ID of a GitHub App that can read `repositories`. |
| `private-key` | None | Private key of that GitHub App. Pass a secret. |
| `repositories` | None | The private repositories that ToolConfig fetches. Write one `owner/name` on each line. All of them must have the same owner. |

Give `client-id`, `private-key` and `repositories` together, or none of them.

## Private shared configuration

When you give the GitHub App inputs, the action does these steps:

1. [actions/create-github-app-token](https://github.com/actions/create-github-app-token)
   makes a token that can only read the contents of `repositories`. The token is
   revoked when the job ends.
2. [mathematic-inc/scoped-git-token-action](https://github.com/mathematic-inc/scoped-git-token-action)
   runs ToolConfig. Git sends the token only for `repositories`, and only this
   step has the token.

Install the GitHub App on each repository in `repositories`. Without the GitHub
App inputs, ToolConfig has no GitHub token, so it can only fetch public
repositories, such as `mathematic-inc/toolconfig-config`.

The CI of this repository does not run the private path, because it needs a
GitHub App and its private key. The CI tests the input rules of the private path
in `tests/contracts.sh`.

## Environment

Pkl in shared configuration can read environment variables. Before ToolConfig
starts, the action removes each variable whose name contains `TOKEN`, `SECRET`,
`PASSWORD`, `ACCESS_KEY`, `PRIVATE_KEY` or `API_KEY`. The scoped Git token is
the only exception.

## Development

```sh
mise run check
```

The `check` task runs `hk check --all --slow` and `tests/contracts.sh`. The
`fix` task runs `hk fix --all`. The `generate` task writes the tool settings,
which Git ignores. They come from the ToolConfig policy in
`mathematic-inc/toolconfig-config`.

The CI also runs the action on the projects in `tests/` on Linux, macOS and
Windows.

## License

MIT. See [LICENSE](LICENSE).
