# helpdesk-agent

**Status:** Active · **Updated:** 2026-10-20 by /ship word-count

Answers a support question with a model that may call tools.

## Run it

| Task | Command |
| ---- | ------- |
| ask  | `python3 -m helpdesk_agent.cli --replay examples/hello.json "How many words are in hello world?"` |

## Slices

| Slice | Status | What it does | Page |
| ----- | ------ | ------------ | ---- |
| word-count | Shipped | The model can count the words in a text | — |
