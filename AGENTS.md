# AGENTS.md

Instructions for AI agents working in this repository. Humans should start with [README.md](README.md), which remains the reference for architecture, security and operations. This file adds what an agent needs to work here safely.

The sections follow the order of the work:

1. [Context](#1-context): what the repository contains and the principles behind it.
2. [Permissions](#2-permissions): what an agent may do alone, after proposing, after asking, or never.
3. [Code](#3-code): how the Terraform code is written.
4. [Documentation](#4-documentation): how documentation is written and structured.
5. [Git and pull requests](#5-git-and-pull-requests): branches, commits and pull requests.
6. [Delivery workflow](#6-delivery-workflow): the steps from the first edit to the merge.
7. [Long-running commands](#7-long-running-commands): how to run and monitor them.
8. [Before handing work back](#8-before-handing-work-back): the final checklist.

## 1. Context

### What this repository is

Infrastructure as code for the Quickesst platform: Terraform modules deployed on Kubernetes (k3s for dev and staging, Scaleway Kapsule for preprod and prod), plus the k3s server configuration and the deployment tasks. The application code (API, BFFs, frontends) lives in other repositories: do not create application code here.

### Principles

Three principles drive every change (README, *Purpose*):

- **Declarative and reproducible**: everything is versioned code, pinned to exact versions.
- **Zero trust**: no implicit trust in the network, encryption in transit and at rest, least privilege.
- **Sovereign and European**: never introduce a non-European provider or a service subject to a non-European jurisdiction.

A change that conflicts with one of them is flagged to the user, not implemented.

### Repository layout

Same list as README.md, *Repository structure* (see [Keeping documentation in sync](#keeping-documentation-in-sync)). Entries marked *(planned)* are not in `main` yet.

```
main.tf                          # root module: variables, providers, S3 backend, module composition
modules/                         # one Terraform module per topic, in modules/<topic>/infra/
  platform/                      # (planned) cert-manager, Cilium (self-managed clusters only)
  postgres/                      # CloudNativePG operator and PostgreSQL cluster (image pinned by digest)
  database/                      # PostgreSQL roles, passwords, pg_hba, databases
  zitadel/                       # Zitadel, its masterkey and database credentials
  backup/                        # (planned) object storage bucket, scoped backup user, ObjectStore, scheduled backups
scripts/
  shipper/
    shipper-infra-deploy.yaml    # Task definitions for deployment (init + apply)
Taskfile.yml                     # Task entry point, loads .env
k3s/                             # k3s server settings for self-managed clusters (dev, staging)
  config.yaml                    # installed as /etc/rancher/k3s/config.yaml
  audit-policy.yaml              # Kubernetes API audit policy
  pod-security.yaml              # Pod Security Admission defaults
flake.nix                        # Nix development shell with pinned tooling (terraform, kubectl, helm, k3d, task, gitleaks, gh...)
flake.lock                       # exact versions of the Nix inputs
.envrc                           # direnv: loads the Nix development shell on entering the directory
.terraform.lock.hcl              # exact provider versions and checksums
.pre-commit-config.yaml          # pre-commit hooks: gitleaks, commit message check
renovate.json                    # dependency update policy (Renovate)
.env.example                     # required environment variables, no values
.gitignore                       # excludes secrets, Terraform state and local artefacts
.github/
  pull_request_template.md       # description template for pull requests
  workflows/pr-checks.yml        # CI on pull requests and main: PR title, Terraform fmt/validate, gitleaks (no secrets)
README.md                        # reference documentation for humans
AGENTS.md                        # instructions for AI agents working in this repository
CLAUDE.md                        # imports AGENTS.md so that Claude Code loads it
```

### Environments and deployment

- `task shipper:default <env>` runs `terraform init` (S3 backend, bucket `qks-infra-<target>`) then `terraform apply`. `production` and `staging` are used as is; any other name becomes `dev-<name>` (personal dev environments).
- `TF_VAR_qks_current_env` is set by the deployment task; never hardcode an environment in a module.
- Local work happens in the k3d cluster `quickesst` created by the Nix shell, using `~/.kube/config`.

## 2. Permissions

### Without asking

- Read any file except `.env`, which contains real credentials.
- Run checks that modify no tracked file and use no credentials: `terraform init -backend=false`, `terraform fmt -check -recursive`, `terraform validate`, `gitleaks detect`.

### After proposing the change and receiving an explicit yes

- Every change to an existing file and every new file, whatever its type, this file included. Present the files concerned, the before/after for an existing file or the full content of a new one, and the reason. Apply only what was approved, and only to the approved files.
- Commands that rewrite files count as changes: `terraform fmt` without `-check`, `pre-commit run` (its hooks may fix files), code generators.
- Say explicitly when a proposal adds a provider, a Helm chart or a new external service.
- An approval covers the change that was presented. Anything added afterwards, even a small fix noticed along the way, is proposed again.

### After asking and receiving an explicit yes

- Commits, pushes and pull requests (see [Git and pull requests](#5-git-and-pull-requests)).
- `terraform init` with the backend, `plan` or `apply`, `task shipper:*`, and any `kubectl` or `helm` command that changes a cluster. A `plan` touches the remote state backend and real credentials.
- Other git operations that change the repository: `git rebase`, `git reset`, `git stash`, branch creation or deletion, tag.

### Never

- `-auto-approve` or `--force`.
- Anything listed as forbidden in [Principles](#principles), [Code](#3-code) and [Git and pull requests](#5-git-and-pull-requests): each prohibition is stated next to the rule it protects.

## 3. Code

### Module pattern

Every module under `modules/<topic>/infra/` follows the same structure. Keep it when adding or changing a module.

```
infra/
  main.tf          # selects the tier, instantiates development/ or production/ with count
  variables.tf     # inputs received from the root module
  outputs.tf       # re-exports the selected tier's outputs
  development/     # thin wrapper: calls ../common with development values
  production/      # thin wrapper: calls ../common with production values
  common/          # the actual implementation
    terraform.tf   # required_providers
    variables.tf
    locals.tf      # names (namespaces, services, field managers…)
    ressources.tf  # resources (the file name is spelled this way on purpose: keep it)
    datas.tf       # data sources, when needed
    outputs.tf
```

- **Tier selection:** `local.qks_tier = startswith(var.qks_current_env, "dev-") ? "development" : "production"`, then `count` on each tier module and `one(concat(...))` to expose the active one. Staging therefore runs the **production** tier.
- **Differences between tiers** are passed as variables from `development/` and `production/` (for example the number of PostgreSQL instances). Do not duplicate resources in the tier folders: implementation stays in `common/`.
- **Naming:** Terraform variables, module names and locals are prefixed with `qks_` / `qks-`. Kubernetes object names live in `common/locals.tf`.
- **Dependencies between modules** are expressed in the root `main.tf` with `depends_on` and by passing outputs (namespace, cluster name, secret names). The intended order is in README, *Dependency order*.
- **Style:** section separators (`# ===== VARIABLES =====`, etc.) are used in larger files; keep the existing style.

### Versions

- Every provider used by a module (root or child) is declared in that module's `required_providers` with an exact version (`version = "x.y.z"`, never `~>`, `>=` or no constraint). A provider used but not declared is resolved by Terraform without any version constraint, so it is not pinned.
- The same provider has the same version in every module.
- Helm charts and container images are pinned to an exact version; images also by digest.
- Updates go through Renovate: never run `terraform init -upgrade`, and never edit `.terraform.lock.hcl` or `flake.lock` by hand.

### Secrets

- Never in code, comments, examples, plans or logs, and no real hostname or IP either (use `example.com` domains and `203.0.113.0/24` addresses in examples).
- Secrets are generated by Terraform (`random_password`) or come from the environment.
- Generated values are long and alphanumeric (64 characters by default, 32 for the Zitadel masterkey), with `special = false`, to avoid escaping issues in connection strings, YAML and shells.

### Critical resources

- Never remove or weaken `lifecycle { prevent_destroy = true }`.
- Never write a change that destroys or replaces a critical resource (Zitadel masterkey, role passwords, PostgreSQL cluster, backup bucket), whether or not it is already protected.

### Network

- Only standard Kubernetes `NetworkPolicy`, default deny per namespace, explicit egress.
- Do not use Cilium-specific resources: the CNI will change when moving to Kosmos.

### Kubernetes manifests

- Manifests applied with `kubectl_manifest` set an explicit `field_manager`, defined in `common/locals.tf`.

### Known pitfalls

Read README, *Known pitfalls*, before touching Zitadel, CloudNativePG or secrets. The most costly ones: the Zitadel config secret key is `config-yaml`, the masterkey must be exactly 32 characters and backed up, and a CloudNativePG `Database` resource silently recreates a dropped database empty.

## 4. Documentation

### Where documentation lives

| File | Audience | Content |
|---|---|---|
| `README.md` | Humans | Reference for the repository: purpose, architecture, structure, prerequisites, getting started, conventions, security, operations, known pitfalls, roadmap. |
| `AGENTS.md` | AI agents | How to work in the repository: permissions, code rules, git and delivery workflow. |
| `docs/<topic>.md` | Humans | A topic too long for the README (a procedure, a design decision, a runbook). Linked from the README. |
| Comments in code | Readers of that file | Why a non-obvious choice was made, never what the code already says. |

Each piece of information has one home. Elsewhere, link to it instead of repeating it: duplicated documentation drifts out of sync.

### Language and tone

- English, plain and direct. Short sentences, active voice, present tense.
- Write for a reader who does not know the context: name things explicitly, define acronyms on first use.
- State facts and rules, not intentions. Mark what does not exist yet with *(planned)*, and state targets as targets ("Target: …").

### Structure of a document

1. **One title** (`#`), naming the subject.
2. **An introduction** of one or two sentences: what the document covers and who it is for.
3. **Sections** (`##`) ordered from context to action to reference: why and what first, then how to use or operate, then details, pitfalls and roadmap last.
4. **Subsections** (`###`) when a section covers several distinct topics. Never skip a heading level.

For a procedure (a runbook, a getting-started guide): prerequisites first, then numbered steps, each with the exact command, then how to check the result.

### Formatting

- Headings in sentence case, without trailing punctuation.
- Numbered lists for ordered steps, bullet lists for parallel items, tables to compare items along the same attributes.
- Bold for the key term of a bullet (`- **Term:** explanation`), not for whole sentences.
- File names, paths, commands, variables and values in backticks. Multi-line commands and code in fenced blocks with a language (`bash`, `hcl`, `yaml`).
- Relative links to other files of the repository; links to sections with their anchors.

### Keeping documentation in sync

- **Structure changes:** adding, removing, renaming or moving a file or a folder updates, in the same pull request:
  - the repository structure in README.md (*Repository structure*) and the layout in this file (*Repository layout*), which must always list the same files;
  - the README *Roadmap* and *Dependency order* when a module is added or removed;
  - every document that names the file, path or command concerned.
- **Other changes:** a change to a module, a convention or a procedure updates the matching documentation in the same pull request.
- Documentation never claims something the code does not do: when code and documentation disagree, flag it to the user and propose a fix to one of them.

## 5. Git and pull requests

### Branches

- One branch per topic, named `<type>/<topic>` (for example `feat/zitadel`, `fix/provider-pinning`), created from an up-to-date `main`.
- No direct commits on `main`: changes reach it through a pull request, merged once the *PR checks* workflow passes.

### Commits

- **Approval:** never commit, push or open a pull request without an explicit yes from the user. Before committing, present the proposed commit: the branch, the exact list of files to stage and the full commit message. Commit only those files, with that message.
- **Staging:** stage files explicitly (`git add <path>`). Never use `git add -A`, `git add .` or `git commit -a`. Check that no `.env`, Terraform state, plan, kubeconfig or key is staged.
- **Message format:** Conventional Commits, `type(scope): subject`, enforced in strict mode by pre-commit. Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`, `build`, `security`. Subject in imperative mood, lowercase, no trailing period, 72 characters max. The body, when needed, explains why the change is made rather than what it does.
- **Scope:** the module or area touched: `postgres`, `database`, `zitadel`, `backup`, `platform`, `k3s`, `shipper`, `deps`, `agents`. Omit it for changes spanning the whole repository.
- **Hooks:** they must pass. Never use `--no-verify`. If gitleaks or the commit message check fails, fix the cause and propose the commit again.
- **History:** never `--amend`, rebase or force push anything already pushed. Strict mode rejects merge and `fixup!` commits.
- **Attribution:** a commit written by an agent ends with a `Co-Authored-By:` trailer naming the agent. Since pull requests are squash-merged and the description becomes the commit body on `main`, the pull request description ends with the same trailer, so that the origin stays visible in the history. Add no other signature line (such as "Generated with …") unless the user asks for it.

### Pull requests

- **One pull request, one logical change.** Pull requests are merged with **squash only**, so each one becomes a single commit on `main`. Do not mix formatting with functional changes in the same pull request. `.terraform.lock.hcl` and `flake.lock` are committed together with the change that updated them.
- **Title:** same format as a commit message (`type(scope): subject`). It becomes the commit message on `main`, and the CI checks it.
- **Description:** follows `.github/pull_request_template.md`, with every section present. A section that does not apply contains only "None"; do not expand it into the template's bullets.

## 6. Delivery workflow

Every change follows the same steps, from the first edit to the merge. The approvals required at each step are listed in [Permissions](#2-permissions).

### Who runs the commands

- **Agent running in the user's shell** (for example a CLI agent started in the Nix shell): it runs the commands itself, after each required approval.
- **Agent reaching the repository through a file bridge** (for example the Claude desktop app): it cannot run the git hooks (they call tools from the user's Nix store), sign commits, push, use `gh` or delete files without approval. It prepares the change and the pull request description, then gives the user the complete [command block](#command-block), adapted to the change.

### Before starting

- Check the current branch without writing to the index: `cat .git/HEAD`, `git log --oneline -3`, `git diff --cached --stat`. Through a file bridge, never run `git status`, `git add`, `git commit` or any other command that writes to `.git/index`: the lock file it creates could not be removed, blocking the user's git.
- Before changing a tracked file, make sure the right branch is checked out, created from an up-to-date `main`; otherwise switch first (or ask the user to). Changing tracked files on the wrong branch blocks `git switch`.

### Code

- Propose the change, then apply it once approved.
- Through a file bridge, write files directly in the repository with shell commands, then read them back to check the result.
- Format with `terraform fmt -recursive`.
- Validate in a clean data directory, so that a previously configured backend and its state are not used: `export TF_DATA_DIR=$(mktemp -d) && terraform init -backend=false && terraform validate; unset TF_DATA_DIR`. If providers changed, the same `init` updates `.terraform.lock.hcl`.

### Git

- Stage only the files of this change with `git add <path>`, then check with `git status`.
- For a multi-line message, write it to `.git/commit-msg-<topic>.txt` (inside `.git/`, like the pull request description) and commit with `git commit -F .git/commit-msg-<topic>.txt`.
- Commit, then confirm with `git log --oneline -1` that the commit exists: a failing hook aborts the commit after printing its output.

### Pull request

- Write the description, following `.github/pull_request_template.md`, to `.git/pr-body-<topic>.md` (inside `.git/`, so it can never be committed), one file per pull request.
- Push, open the pull request with `gh pr create`, follow the checks with `gh pr checks --watch` (see [Long-running commands](#7-long-running-commands)), then merge with `gh pr merge --squash` once the three checks pass.

### Cleanup

- Update `main` and delete the local branch with `git branch -D`: git does not see squash-merged branches as merged.
- Delete the description and commit message files.

### Command block

From the repository root, in the Nix shell:

```bash
git switch main && git pull
git switch -c <type>/<topic>
terraform fmt -recursive
export TF_DATA_DIR=$(mktemp -d) && terraform init -backend=false && terraform validate; unset TF_DATA_DIR
git add <paths>
git status
git commit -m "<type>(<scope>): <subject>"
git log --oneline -1
git push -u origin <type>/<topic>
gh pr create --base main --head <type>/<topic> --title "<type>(<scope>): <subject>" --body-file .git/pr-body-<topic>.md
gh pr checks --watch
gh pr merge --squash
git switch main && git pull && git branch -D <type>/<topic>
rm -f .git/pr-body-<topic>.md .git/commit-msg-<topic>.txt
```

## 7. Long-running commands

For full test suites and any other command expected to take more than a few minutes, whatever its nature (Terraform tests, cluster checks, application suites…):

- Start the command once, write its output to a log, and keep its process/session handle and exit status.
- Prefer completion notifications or a blocking process wait over model-driven polling. If polling is necessary, check no more often than every 15 minutes while the command is running.
- Assign one agent to monitor the run. Controllers and other agents must not independently poll the same process, scan its logs, or ask the monitoring agent for routine updates between checks.
- Report completion, a stage transition or an actionable failure promptly when notified. An explicit status request from the user is also answered; routine minute-by-minute messages are not required.
- Do not rerun a suite merely because it has been quiet or is taking a long time. Investigate only after a recorded failure, a timeout, or evidence that the process has stopped.
- Keep for the final report: the commands run, the logs, the snapshot identity (commit and state of the working tree that was tested), the actual exit codes, failures and skips. Waiting time must not be filled with extra review agents or audits unless the user requests them.

This protocol applies to delegated agents as well as the controller. It changes monitoring frequency, not the required test coverage or the accuracy of reported results.

## 8. Before handing work back

1. The checks listed in [Permissions](#without-asking) pass: `terraform fmt -check -recursive`, `terraform validate`, `gitleaks detect`. The *PR checks* workflow runs the same checks on the pull request.
2. The documentation is up to date, as required by [Keeping documentation in sync](#keeping-documentation-in-sync): propose the updates that are still missing.
3. Summarise what changed and list what needs a `plan`, an apply or a commit, so the user can decide. If tests were run, include the report described in [Long-running commands](#7-long-running-commands).
