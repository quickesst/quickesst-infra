# AGENTS.md

Instructions for AI coding agents working in this repository. Humans should start with [README.md](README.md), which remains the reference for architecture, security and operations. This file only adds what an agent needs to work here safely.

It reads in order: what the repository contains, how its code is written, what an agent may do, how changes are committed, and how work is handed back.

## What this repository is

Infrastructure as code for the Quickesst platform: Terraform modules deployed on Kubernetes (k3s for dev and staging, Scaleway Kapsule for preprod and prod), plus the k3s server configuration and the deployment tasks. The application code (API, BFFs, frontends) lives in other repositories: do not create application code here.

Three principles drive every change (README, *Purpose*): **declarative and reproducible**, **zero trust**, **sovereign and European**. A change that conflicts with one of them is flagged to the user, not implemented. In particular, never introduce a non-European provider or a service subject to a non-European jurisdiction.

## Repository layout

```
main.tf                     # root module: variables, providers, S3 backend, module composition
modules/<topic>/infra/      # one Terraform module per topic (see "Module pattern")
  platform/                 # empty for now: cert-manager, Cilium (planned)
  postgres/                 # CloudNativePG operator and PostgreSQL cluster
  database/                 # roles, passwords, pg_hba, databases
  zitadel/                  # Zitadel, its masterkey and database credentials
  backup/                   # MinIO bucket, scoped backup user, ObjectStore
scripts/shipper/            # Task definitions for deployment (init + apply)
Taskfile.yml                # Task entry point, loads .env
k3s/                        # k3s server config for self-managed clusters (copied to /etc/rancher/k3s/)
flake.nix / flake.lock      # Nix dev shell with pinned tooling (terraform, kubectl, helm, k3d, task, gitleaks…)
.envrc                      # direnv: loads the Nix shell
.terraform.lock.hcl         # exact provider versions and checksums
.pre-commit-config.yaml     # gitleaks + Conventional Commits check on commit messages
renovate.json               # dependency update policy
.env.example                # required variables, no values
CLAUDE.md                   # imports this file so that Claude Code loads it
```

## Module pattern

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
- **Differences between tiers are passed as variables** from `development/` and `production/` (for example the number of PostgreSQL instances). Do not duplicate resources in the tier folders: implementation stays in `common/`.
- **Naming:** Terraform variables, module names and locals are prefixed with `qks_` / `qks-`. Kubernetes object names live in `common/locals.tf`.
- **Dependencies between modules** are expressed in the root `main.tf` with `depends_on` and by passing outputs (namespace, cluster name, secret names). The intended order is in README, *Dependency order*.
- Section separators (`# ===== VARIABLES =====`, etc.) are used in larger files: keep the existing style.

## Environments and deployment

- `task shipper:default <env>` runs `terraform init` (S3 backend, bucket `qks-infra-<target>`) then `terraform apply`. `production` and `staging` are used as is; any other name becomes `dev-<name>` (personal dev environments).
- `TF_VAR_qks_current_env` is set by the deployment task; never hardcode an environment in a module.
- Local work happens in the k3d cluster `quickesst` created by the Nix shell, using `~/.kube/config`.

## Writing code

- **Versions:** every provider used by a module (root or child) is declared in that module's `required_providers` with an exact version (`version = "x.y.z"`, never `~>`, `>=` or no constraint). A provider used but not declared is resolved by Terraform without any version constraint, so it is not pinned. The same provider has the same version in every module. Helm charts are pinned to an exact `version` too. Updates go through Renovate: never run `terraform init -upgrade`, and never edit `.terraform.lock.hcl` or `flake.lock` by hand.
- **Secrets:** never in code, comments, examples, plans or logs, and no real hostname or IP either. Secrets are generated by Terraform (`random_password`) or come from the environment. Generated values are long and alphanumeric (64 characters by default, 32 for the Zitadel masterkey), with `special = false`, to avoid escaping issues in connection strings, YAML and shells.
- **Critical resources:** never remove or weaken `lifecycle { prevent_destroy = true }`, and never write a change that destroys or replaces a critical resource (Zitadel masterkey, role passwords, PostgreSQL cluster, backup bucket), whether or not it is already protected.
- **Network:** only standard Kubernetes `NetworkPolicy`, default deny per namespace, explicit egress. Do not use Cilium-specific resources: the CNI will change when moving to Kosmos.
- **Kubernetes manifests applied with `kubectl_manifest`** set an explicit `field_manager`.
- **Language:** code, comments, documentation and commit messages in English.
- **Known pitfalls:** read README, *Known pitfalls*, before touching Zitadel, CloudNativePG or secrets. The most costly ones: the Zitadel config secret key is `config-yaml`, the masterkey must be exactly 32 characters and backed up, and a CloudNativePG `Database` resource silently recreates a dropped database empty.

## What an agent may do

**Without asking:**

- Read any file except `.env`, which contains real credentials.
- Run checks that modify no tracked file and use no credentials: `terraform init -backend=false`, `terraform fmt -check -recursive`, `terraform validate`, `gitleaks detect`.

**Only after proposing the change and receiving an explicit yes:**

- Every change to an existing file and every new file, whatever its type, this file included. Present the files concerned, the before/after for an existing file or the full content of a new one, and the reason. Apply only what was approved, and only to the approved files.
- Commands that rewrite files count as changes: `terraform fmt` without `-check`, `pre-commit run` (its hooks may fix files), code generators.
- Say explicitly when a proposal adds a provider, a Helm chart or a new external service.
- An approval covers the change that was presented. Anything added afterwards, even a small fix noticed along the way, is proposed again.

**Only after asking and receiving an explicit yes:**

- `terraform init` with the backend, `plan` or `apply`, `task shipper:*`, and any `kubectl` or `helm` command that changes a cluster. A `plan` touches the remote state backend and real credentials.
- Git operations that change the repository other than commits: `git rebase`, `git reset`, `git stash`, branch creation or deletion, tag. Commits and pushes follow *Commits*.

**Never:** `-auto-approve` or `--force`. The other prohibitions are stated with the rule they protect, in *What this repository is*, *Writing code* and *Commits*.

## Commits

- **Never commit or push without an explicit yes from the user.** Before committing, present the proposed commit: the branch, the exact list of files to stage and the full commit message. Commit only those files, with that message.
- **Stage files explicitly** (`git add <path>`). Never use `git add -A`, `git add .` or `git commit -a`. Check that no `.env`, Terraform state, plan, kubeconfig or key is staged.
- **Message format:** Conventional Commits, `type(scope): subject`, enforced in strict mode by pre-commit. Allowed types: `feat`, `fix`, `chore`, `docs`, `refactor`, `ci`, `build`, `security`. Subject in imperative mood, lowercase, no trailing period, 72 characters max. The body, when needed, explains why the change is made rather than what it does.
- **Scope:** the module or area touched: `postgres`, `database`, `zitadel`, `backup`, `platform`, `k3s`, `shipper`, `deps`, `agents`. Omit it for changes spanning the whole repository.
- **One commit, one logical change.** Do not mix formatting with functional changes. `.terraform.lock.hcl` and `flake.lock` are committed together with the change that updated them.
- **Hooks must pass.** Never use `--no-verify`. If gitleaks or the commit message check fails, fix the cause and propose the commit again.
- **History:** never `--amend`, rebase or force push anything already pushed. Strict mode rejects merge and `fixup!` commits.
- **Branches:** one branch per topic, named `<type>/<topic>` (for example `feat/zitadel`, `fix/provider-pinning`). No direct commits on `main`: changes reach it through a reviewed pull request.
- **Attribution:** a commit written by an agent ends with a `Co-Authored-By:` trailer naming the agent, so that its origin stays visible in the history.

## Long-running test suites and commands

For full test suites and any other command expected to take more than a few minutes, whatever its nature (Terraform tests, cluster checks, application suites…):

- Start the command once, write its output to a log, and keep its process/session handle and exit status.
- Prefer completion notifications or a blocking process wait over model-driven polling. If polling is necessary, check no more often than every 15 minutes while the command is running.
- Assign one agent to monitor the run. Controllers and other agents must not independently poll the same process, scan its logs, or ask the monitoring agent for routine updates between checks.
- Report completion, a stage transition or an actionable failure promptly when notified. An explicit status request from the user is also answered; routine minute-by-minute messages are not required.
- Do not rerun a suite merely because it has been quiet or is taking a long time. Investigate only after a recorded failure, a timeout, or evidence that the process has stopped.
- Keep for the final report: the commands run, the logs, the snapshot identity (commit and state of the working tree that was tested), the actual exit codes, failures and skips. Waiting time must not be filled with extra review agents or audits unless the user requests them.

This protocol applies to delegated agents as well as the controller. It changes monitoring frequency, not the required test coverage or the accuracy of reported results.

## Before handing work back

1. The checks listed in *What an agent may do* pass: `terraform fmt -check -recursive`, `terraform validate`, `gitleaks detect`.
2. If the change touches the structure, the module list or a convention, propose the matching updates to README.md (*Repository structure*, *Roadmap*) and to this file.
3. Summarise what changed and list what needs a `plan`, an apply or a commit, so the user can decide. If tests were run, include the report described in *Long-running test suites and commands*.