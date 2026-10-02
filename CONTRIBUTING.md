<!-- SPDX-License-Identifier: GPL-3.0-only -->
<!-- Copyright (C) 2026 kaayzouee -->
<!-- Author: https://github.com/kaayzouee -->

# Contributing to neodots

Thank you for contributing to neodots. Keep changes focused, reproducible, and easy to review.

## Before you start

For non-trivial changes, search existing issues and pull requests first. Prefer opening an issue when the intended behavior or design is not already documented.

Do not commit secrets or sensitive machine-specific data. In particular, never add decrypted SOPS secrets, private keys, access tokens, passwords, or credentials to the repository.

## Repository-specific expectations

neodots is a NixOS configuration repository. Changes should preserve declarative, reproducible behavior and avoid hard-coded machine-specific values unless they are explicitly part of a host definition.

When changing Nix code:

- Keep host-specific configuration under the appropriate host definition.
- Prefer reusable modules over copying configuration between hosts.
- Keep dependencies and inputs reproducible through `flake.lock`.
- Validate evaluation/build behavior before opening a PR.
- Avoid unrelated formatting or refactoring in the same change.

When changing GitHub Actions or other automation:

- Use least-privilege permissions.
- Do not use privileged pull-request execution patterns for untrusted code.
- Keep third-party actions pinned according to the repository's security policy.
- Run the relevant workflow/security linting locally when practical.

## Branches

Use a short, descriptive branch name. Recommended prefixes are:

- `feat/` — new functionality
- `fix/` — bug fix
- `docs/` — documentation
- `refactor/` — refactoring without intended behavior change
- `ci/` — CI/CD and automation
- `security/` — security-related work
- `chore/` — maintenance

Example:

`feat/machine-aware-installer`

Do not work directly on `main` for normal contribution work.

## Commit messages

Use the Conventional Commits style:

`<type>(<scope>): <imperative description>`

Examples:

- `feat(installer): add machine-aware configuration generation`
- `fix(modules): correct wallpaper persistence path`
- `docs(readme): update installation instructions`
- `ci(actions): add flake validation`
- `security(actions): pin workflow dependencies`
- `refactor(hosts): remove duplicated hardware options`
- `chore(flake): update locked inputs`

### Commit rules

- Use an imperative description: `add`, `fix`, `update`, `remove`, not `added` or `adding`.
- Keep the subject concise and specific; avoid ending it with a period.
- Use a scope when it improves clarity. Prefer repository areas such as `flake`, `hosts`, `modules`, `packages`, `installer`, `docs`, `ci`, or `security`.
- Keep each commit atomic: one logical change per commit.
- Avoid mixing unrelated formatting changes, dependency updates, and feature work.
- Write the body when the change needs context, design rationale, migration notes, or a non-obvious trade-off.
- Reference issues in the commit body or PR when useful, but do not rely on commit messages alone for detailed issue tracking.
- Fixup/squash local work before requesting review when practical so the final history is coherent.

### Allowed commit types

Use the type that best describes the primary purpose:

- `feat` — new functionality
- `fix` — bug fix
- `docs` — documentation-only changes
- `refactor` — code restructuring without intended behavior change
- `perf` — performance improvement
- `test` — tests or validation
- `ci` — CI/CD and automation
- `build` — build/dependency infrastructure
- `security` — security-specific changes
- `chore` — maintenance that does not fit another type

Breaking changes should be called out explicitly in the commit body and PR description. A `!` before the colon may also be used, for example:

`feat(modules)!: rename the wallpaper option`

## Validation

Before opening a PR, run the checks relevant to your change. At minimum, validate Nix evaluation with:

```bash
nix flake check
```

For changes that affect a specific host or build target, also build the affected target without switching the live system. For example:

```bash
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

Also check for whitespace errors:

```bash
git diff --check
```

Run formatting, linting, tests, or security checks added by the repository's CI when they apply to your change.

Do not use `nixos-rebuild switch` as a substitute for CI validation. A pull request should validate the configuration before changing a live machine.

## Pull requests

A good PR should:

1. Explain the problem and intended behavior.
2. Keep the diff focused.
3. Include relevant tests/checks and their results.
4. Call out migration or compatibility impact.
5. Update documentation when user-visible behavior changes.
6. Identify security implications for changes involving secrets, permissions, dependencies, installers, or CI.

Prefer small, reviewable pull requests over large mixed-purpose changes.

## Security issues

Do not report undisclosed vulnerabilities, credentials, or exploit material in a public issue. Use the repository's private security reporting mechanism when one is configured, or contact the maintainers privately.

Never commit proof-of-concept secrets, real credentials, decrypted SOPS files, or private keys.

## Generated and machine-specific files

Do not commit local machine artifacts unless they are intentionally part of the repository. Pay particular attention to hardware configuration, decrypted secret files, temporary outputs, and generated build results.

Check the repository's `.gitignore` before adding a new generated or machine-specific file.

## Review and merge

Reviewers may request changes to scope, architecture, tests, documentation, security controls, or commit history.

Before merge, make sure:

- CI is passing.
- The PR description accurately reflects the final change.
- Required documentation is present.
- No sensitive material has been introduced.
- The final commit history is understandable and consistent with this guide.
