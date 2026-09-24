# A run-once step needs a path for repos that predate it

**Learned:** 2026-09-24 · **From:** readme-block build (ledger O5)

Onboarding runs once and never again after the overview is Active. The
readme-block slice added a README step to onboarding and a gate that fails
without the block — so every repo onboarded earlier, this one included, would
fail the gate with no stage that fixes it.

When a slice adds an artifact to a run-once step and a gate that requires it,
give the recurring stage (`/ship`) a path to add it to repos that predate the
step, and name that exception in the run-once reference.
