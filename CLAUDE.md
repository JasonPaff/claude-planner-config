# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

This is a configuration repository for AI-powered DevOps automation. It contains:
- **Azure Pipelines configuration** for AI-assisted development workflows
- **Claude Code skills, commands, and agents** that are copied into target repositories during pipeline execution
- **Shell scripts** for Azure DevOps and GitHub integration

The `.claude/` configuration is designed to be deployed to other repositories (primarily `head-shakers`) where the actual development happens.

## Architecture

```
claude-planner-config/
├── azure-pipelines.yml      # Main pipeline - triggered via REST API
├── scripts/                 # Integration scripts for Azure DevOps and GitHub
│   ├── fetch-work-item.sh   # Fetches work item details from Azure DevOps
│   ├── attach-plan.sh       # Attaches implementation plans to work items
│   └── create-pr.sh         # Creates GitHub PRs and links to work items
└── .claude/                 # Claude Code configuration (deployed to target repos)
    ├── agents/              # Specialized subagents for specific tasks
    ├── commands/            # User-invocable slash commands
    └── skills/              # Domain knowledge and conventions
```

## Pipeline Workflows

The pipeline supports three workflow types triggered via the `workflowType` parameter:

### `quick-fix`
- For trivial issues (typos, one-line fixes)
- 5-minute timeout
- Automatically bails out if issue is too complex
- On success: creates branch and PR

### `plan`
- For feature planning (runs `/plan-feature`)
- 30-minute timeout
- Generates implementation plan attached to work item
- No code changes, just planning artifacts

### `implement`
- For executing approved plans (runs `/implement-plan`)
- 60-minute timeout
- Downloads plan from work item, implements changes
- Creates branch and PR with implementation

## Key Commands

| Command | Description |
|---------|-------------|
| `/quick-fix "issue"` | Fix trivial issues, bail out if complex |
| `/plan-feature "feature"` | 3-step orchestration: refine → discover files → plan |
| `/implement-plan path.md` | Execute plan using specialist subagents |
| `/code-review "area"` | Parallel specialist review with consolidated report |
| `/db operation` | Neon database operations via expert agent |

## Agent Architecture

Commands use an **orchestrator + specialist** pattern:

1. **Orchestrator** (the command) - coordinates workflow, manages todos, routes tasks
2. **Specialists** - domain-specific agents with pre-loaded skills:
   - `server-action-specialist`, `database-specialist`, `facade-specialist`
   - `server-component-specialist`, `client-component-specialist`, `form-specialist`
   - `unit-test-specialist`, `component-test-specialist`, `integration-test-specialist`, `e2e-test-specialist`
   - `validation-specialist`, `media-specialist`, `resend-specialist`

Specialists automatically load relevant skills and follow consistent conventions.

## Pipeline Environment

- **Target repository**: GitHub (`JasonPaff/head-shakers` by default)
- **Work item source**: Azure DevOps (`jasonpaffES/Head Shakers`)
- **Required secrets**: `ANTHROPIC_API_KEY`, `GITHUB_PAT` (in Azure DevOps variable group `AI`)
- **Platform**: `ubuntu-latest`
- **Node version**: 20.x

## Modifying This Repository

When changing pipeline or scripts:
- Pipeline uses `--dangerously-skip-permissions` flag for non-interactive execution
- Scripts expect specific environment variables (`AZURE_DEVOPS_ORG`, `GITHUB_PAT`, etc.)
- Output uses Azure DevOps logging commands (`##vso[task.setvariable]`, `##vso[task.logissue]`)

When changing `.claude/` configuration:
- Changes affect behavior in **target repositories** after pipeline copies the config
- Test changes by running commands locally with the target repo
- Skills in `skills/` define domain conventions; agents in `agents/` define specialist behaviors
- Commands in `commands/` define user-invocable workflows
