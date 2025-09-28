# GitHub Copilot CLI Feature

This Dev Container Feature installs the [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli) so you can use Copilot agents directly from your terminal inside VS Code Dev Containers and GitHub Codespaces. The feature ensures the CLI binary is available for root and non-root users, installs the required Node.js runtime, and (optionally) brings in the GitHub CLI to simplify authentication workflows.

## Installed components

- [GitHub Copilot CLI](https://github.com/github/copilot-cli) (`copilot` binary from the `@github/copilot` npm package)
- Node.js 22.x runtime and npm 10+
- Optional: GitHub CLI (`gh`) when `withGH=true`
- Optional: shell completions for bash and zsh (when supported by the CLI)

## Options

| Option | Type | Default | Description |
| ------ | ---- | ------- | ----------- |
| `version` | string | `"latest"` | Install a specific npm release of `@github/copilot` (for example `"0.0.328"`). The special value `latest` installs the newest release if the CLI is not already present. |
| `installCompletions` | boolean | `true` | Attempt to generate and install bash/zsh completions when supported by the CLI. If completions are not yet available, the feature logs and continues. |
| `withGH` | boolean | `true` | Ensure the GitHub CLI is installed. If the platform does not provide packages (for example some Alpine images), a warning is emitted and installation continues. |
| `autoUpdate` | boolean | `false` | When `version=latest`, automatically update to the most recent release on every rebuild. When `false`, the feature is idempotent and will leave the installed version untouched. |

## Usage

Add the feature to your `devcontainer.json` or `devcontainer-feature.json`:

```jsonc
{
  "features": {
    "./src/copilot-cli": {
      "version": "latest",
      "installCompletions": true,
      "withGH": true,
      "autoUpdate": false
    }
  }
}
```

After the container rebuilds, verify the installation as any user inside the environment:

```bash
copilot --version
copilot --help
which copilot
```

## Authentication

1. **Sign in with the GitHub CLI (recommended)**
   - Run `gh auth login --web` or `gh auth login --device` inside the container.
   - Enable the Copilot scopes when prompted, or ensure your existing token includes Copilot access.
2. **Authenticate inside Copilot CLI**
   - Launch the CLI with `copilot` and run `/login` when prompted.
   - Follow the on-screen device code or paste a fine-grained PAT with the "Copilot Requests" permission enabled.

### Codespaces specifics

- Codespaces already provisions the GitHub CLI. With `withGH=true`, the feature simply verifies that `gh` is available.
- Device-code authentication opens in your local browser. When using Codespaces in the browser, the device flow automatically opens a new tab. When using the VS Code desktop client, copy the URL/code as instructed.

### Local Dev Containers

- Ensure your host browser can reach `github.com/login/device`. For corporate proxies, configure the container-wide `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` variables before building.
- If you rely on enterprise-issued CA certificates, install them via the base image or another feature so that Node.js and the GitHub CLI trust your MITM proxy.

## Completions

When `installCompletions=true`, the feature attempts to generate completions using `copilot help completion --shell <bash|zsh>` and places them in `/etc/bash_completion.d/copilot` and `/usr/local/share/zsh/site-functions/_copilot`. If the CLI does not yet expose a completion helper, the script logs a message and continues without failing.

## Auto-updates and idempotency

- By default, the feature installs Copilot CLI only once. Subsequent rebuilds keep the existing version to avoid unexpected behavior changes.
- Set `autoUpdate=true` to refresh to the newest release on every rebuild when `version=latest`.
- To pin a release, set `version` to an explicit npm version string.

## Troubleshooting

| Symptom | Possible fix |
| ------- | ------------- |
| `copilot` command missing | Ensure the feature completed successfully and `/usr/local/bin` is on `PATH`. Rebuild the container to retry. |
| Network or proxy errors during install | Configure `HTTP_PROXY`, `HTTPS_PROXY`, and `NO_PROXY` environment variables. Verify the proxy trusts GitHub domains and Node.js download hosts. |
| Authentication loops | Verify your GitHub account has an active Copilot subscription and the feature policy allows the CLI. Check Copilot organization policies if applicable. |
| GitHub CLI installation warning on Alpine | Alpine repositories may not contain `github-cli`. Install it manually from a compatible source or set `withGH=false`. |

## References

- [Use the GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli)
- [github/copilot-cli repository](https://github.com/github/copilot-cli)
