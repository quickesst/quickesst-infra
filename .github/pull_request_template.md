## Summary

<!-- What this pull request does, in one or two sentences. -->

## Why

<!-- The problem it solves or the need behind it. Link the ticket if there is one. -->

## Changes

<!-- Main changes, grouped by module or area. -->

-

## Infrastructure impact

<!-- Fill in for any Terraform, Helm or k3s change. Write "None" for documentation-only changes. -->

- **Environments affected:** <!-- dev / staging / preprod / prod -->
- **Plan summary:** <!-- x to add, y to change, z to destroy -->
- **Destroy or replacement:** <!-- None, or list the resources and why -->
- **Protected resources touched:** <!-- None, or list (Zitadel masterkey, role passwords, PostgreSQL cluster, backup bucket) -->
- **Manual steps:** <!-- None, or what must be done before or after apply -->

## Security

- [ ] No secret, token, password, real hostname or IP in code, comments, examples or logs
- [ ] New providers, charts or services are European and pinned to an exact version
- [ ] Network flows opened explicitly, no Cilium-specific resources

## Checks

- [ ] `terraform fmt -check -recursive` passes
- [ ] `terraform validate` passes
- [ ] `gitleaks detect` finds nothing
- [ ] README.md and AGENTS.md updated if the structure, a module or a convention changed

## Notes

<!-- Follow-ups, known limitations, anything reviewers should know. -->