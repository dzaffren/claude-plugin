# 3. Ship as a pip package

## Status

Accepted

## Context

Finance staff run the tool on their own laptops. They already have Python installed by
IT. They do not have Docker.

## Decision

We ship invoice-cli as a pip package on the internal index.

## Consequences

Every release needs a version bump.
