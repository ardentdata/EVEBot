# EVEBot Fork Maintenance

This checkout is the maintained Ardent Data fork of `CyberTech/EVEBot`.

## Repository Layout

- `origin`: `ssh://git@ssh.github.com:443/ardentdata/EVEBot.git`
- `upstream`: `https://github.com/CyberTech/EVEBot.git` for fetch, with upstream push disabled locally
- production branch: `master`

Keep upstream and local work separate:

- `upstream/master` is the base source from CyberTech.
- `origin/master` is the Ardent Data maintained fork.
- temporary work should happen on `codex/<task-name>` or another topic branch.

## Routine Upstream Check

From the repository root:

```powershell
.\tools\Update-Upstream.ps1
```

That fetches `upstream`, reports whether this branch is ahead or behind, and lists upstream commits that are not in the current branch.

When ready to bring upstream changes into the current branch:

```powershell
.\tools\Update-Upstream.ps1 -Merge
```

The default merge mode is fast-forward only. If the fork has diverged and needs a merge commit, review the incoming commits first, then run:

```powershell
.\tools\Update-Upstream.ps1 -Merge -AllowMergeCommit
```

## Compare A Local EVEBot Tree

Use this when a test environment has hand-edited scripts that need to be inventoried before we merge them into the maintained fork.

```powershell
.\tools\Compare-EVEBotTree.ps1 -OtherPath "C:\Path\To\Test\EVEBot" -Reference upstream/master -Fetch
```

Common references:

- `upstream/master`: compare the test tree to the original base source.
- `HEAD`: compare the test tree to the currently checked-out fork branch.
- `origin/master`: compare the test tree to the latest pushed Ardent Data master.

The script reports files added, removed, and modified in the other tree. It intentionally ignores `.git`, logs, and the runtime config patterns already ignored by the repository.

For the Ardent Data operational import, use Stable-only mode:

```powershell
.\tools\Compare-EVEBotTree.ps1 -OtherPath "V:\scripts\evebot" -Reference upstream/master -StableOnly -IgnoreCrAtEol
```

Stable-only mode ignores `Branches/Dev`, debug scripts, generated behavior include files, local analysis/tooling folders, backups, Stable runtime config/logs, and runtime logs while keeping launcher/config files that are part of the private deployment workflow. `-IgnoreCrAtEol` suppresses CRLF-only drift so reports focus on content changes.

## Suggested Merge Plan For Test Environments

When we are ready for the larger merge project:

1. Run `Compare-EVEBotTree.ps1` against each test environment with `-Reference upstream/master`.
2. Save both outputs so we can classify intentional changes, runtime-only files, and drift from old upstream code.
3. Create one branch per environment, import only intentional source/config-example changes, and commit those separately.
4. Diff the two branches against each other to identify conflicts and duplicated fixes.
5. Merge the reviewed result into `master`, push to `origin`, then use this fork as the source of truth going forward.

## Development And Deployment

Use this repository as the source of truth. Make changes on a topic branch, commit them, merge to `master`, then deploy from `master` to the two InnerSpace installs.

Default test deployment targets:

- local: `C:\InnerSpace\Scripts\EVEBot`
- remote mapped machine: `V:\Scripts\EVEBot`

Preview a deployment without copying files:

```powershell
.\tools\Deploy-EVEBot.ps1 -WhatIf
```

Deploy to both test installs:

```powershell
.\tools\Deploy-EVEBot.ps1
```

Deploy only one side:

```powershell
.\tools\Deploy-EVEBot.ps1 -Target Local
.\tools\Deploy-EVEBot.ps1 -Target Remote
```

The deploy tool copies only tracked, intentional deployment files. It does not delete target files, and it skips generated files, backups, logs, debug test scripts, maintenance docs/tools, and local analysis folders.

The deploy tool refuses to run from a dirty working tree unless `-AllowDirty` is passed. Use that override only for temporary local testing.
