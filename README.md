# GitHub Copilot CLI Dev Container Feature

This repository packages a Dev Container Feature that installs and configures the [GitHub Copilot CLI](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/use-copilot-cli) inside VS Code Dev Containers and GitHub Codespaces.

## Contents

- `src/copilot-cli`: Feature implementation (`feature.json`, install script, documentation).
- `test/`: Automated tests using the Dev Container Features test harness.
- `examples/`: Sample `devcontainer.json` configurations.

## Getting started

1. Build the feature locally:
   ```bash
   devcontainer features build src/copilot-cli
   ```
2. Run tests:
   ```bash
   devcontainer features test src/copilot-cli
   ```
3. Publish to a registry once you're satisfied (for example GitHub Container Registry):
   ```bash
   devcontainer features publish src/copilot-cli --namespace your-org/features
   ```

## Distribution

- **GitHub Actions workflow** – `.github/workflows/publish.yml` publishes the feature collection to `ghcr.io` whenever you push a semantic tag (for example `v0.1.0`) or trigger the workflow manually.
- **Local helper script** – `distribution/local-ubuntu-docker.sh` replicates the automated publish process on an Ubuntu host with Docker installed. It runs the Dev Containers CLI from a container so no additional tooling is required on the host.

See `src/copilot-cli/README.md` for feature usage details and options.
