# dzafran-claude-plugins

Personal Claude Code plugin marketplace. One plugin: **dz-workflow**.

## dz-workflow

An end-to-end delivery workflow. Each stage is a skill you can invoke as a
slash command; each documentation stage produces Markdown (source of truth)
plus a self-contained HTML visualization you review before approving the next
stage.

```mermaid
flowchart LR
    D[/discover/] -- brief.md + html --> S[/spec/]
    S -- spec.md + html, approval gate --> R[/refine/]
    R -- technical plan, approval gate --> B[/build/]
    B -- code + tests green --> Q[/quality/]
    Q -- findings fixed --> X[/security/]
    X -- no criticals --> P[/ship/]
```

| Command     | What it does                                                        |
| ----------- | ------------------------------------------------------------------- |
| `/discover` | Product discovery session → discovery brief                         |
| `/spec`     | Requirements doc with diagrams, stops for your approval             |
| `/refine`   | Technical plan appended to the spec, stops for your approval        |
| `/build`    | Implements scenario by scenario with tests, on a branch             |
| `/quality`  | Fresh-eyes code review of the diff, safe fixes applied              |
| `/security` | Security review of the diff: secrets, injection, authz, deps        |
| `/ship`     | Verifies all gates, tidies branch, prepares (never pushes) the PR   |
| `spec-html` | Shared renderer: any doc .md → sibling self-contained .html         |

Docs land in `docs/discovery/` and `docs/specs/` of whatever repo you run the
workflow in.

## Install

```
/plugin marketplace add <this repo path or git URL>
/plugin install dz-workflow@dzafran-claude-plugins
```
