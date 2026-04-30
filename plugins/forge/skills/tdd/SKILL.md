---
name: tdd
description: Test-driven development with red-green-refactor loop. Use when user wants to build features or fix bugs using TDD, mentions "red-green-refactor", wants integration tests, or asks for test-first development.
---

# Test-Driven Development

## Reference Guides

| File                                       | What it covers                                                                 |
| ------------------------------------------ | ------------------------------------------------------------------------------ |
| [tests.md](tests.md)                       | Good vs bad test examples, integration-style patterns                          |
| [mocking.md](mocking.md)                   | When to mock (system boundaries only), DI patterns, SDK-style interfaces       |
| [interface-design.md](interface-design.md) | Designing testable interfaces: accept deps, return results, small surface area |
| [deep-modules.md](deep-modules.md)         | Small interface + deep implementation principle                                |
| [refactoring.md](refactoring.md)           | Refactor candidates to look for after GREEN                                    |

## Philosophy

**Core principle**: Tests should verify behavior through public interfaces, not implementation details. Code can change entirely; tests shouldn't.

**Good tests** are integration-style: they exercise real code paths through public APIs. They describe _what_ the system does, not _how_ it does it. A good test reads like a specification - "user can checkout with valid cart" tells you exactly what capability exists. These tests survive refactors because they don't care about internal structure.

**Bad tests** are coupled to implementation. They mock internal collaborators, test private methods, or verify through external means (like querying a database directly instead of using the interface). The warning sign: your test breaks when you refactor, but behavior hasn't changed. If you rename an internal function and tests fail, those tests were testing implementation, not behavior.

See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.

## Anti-Pattern: Horizontal Slices

**DO NOT write all tests first, then all implementation.** This is "horizontal slicing" - treating RED as "write all tests" and GREEN as "write all code."

This produces **crap tests**:

- Tests written in bulk test _imagined_ behavior, not _actual_ behavior
- You end up testing the _shape_ of things (data structures, function signatures) rather than user-facing behavior
- Tests become insensitive to real changes - they pass when behavior breaks, fail when behavior is fine
- You outrun your headlights, committing to test structure before understanding the implementation

**Correct approach**: Vertical slices via tracer bullets. One test → one implementation → repeat. Each test responds to what you learned from the previous cycle. Because you just wrote the code, you know exactly what behavior matters and how to verify it.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED→GREEN: test1→impl1
  RED→GREEN: test2→impl2
  RED→GREEN: test3→impl3
  ...
```

## Workflow

### 1. Planning

Before writing any code:

- [ ] Confirm with user what interface changes are needed
- [ ] Confirm with user which behaviors to test (prioritize)
- [ ] Identify opportunities for [deep modules](deep-modules.md) (small interface, deep implementation)
- [ ] Design interfaces for [testability](interface-design.md)
- [ ] List the behaviors to test (not implementation steps)
- [ ] Get user approval on the plan

Ask: "What should the public interface look like? Which behaviors are most important to test?"

**You can't test everything.** Confirm with the user exactly which behaviors matter most. Focus testing effort on critical paths and complex logic, not every possible edge case.

### 2. Tracer Bullet

Write ONE test that confirms ONE thing about the system:

```
RED:   Write test for first behavior → test fails
GREEN: Write minimal code to pass → test passes
```

This is your tracer bullet - proves the path works end-to-end.

### 3. Incremental Loop

For each remaining behavior:

```
RED:   Write next test → fails
GREEN: Minimal code to pass → passes
```

Rules:

- One test at a time
- Only enough code to pass current test
- Don't anticipate future tests
- Keep tests focused on observable behavior

### 4. Refactor

After all tests pass, look for [refactor candidates](refactoring.md):

- [ ] Extract duplication
- [ ] Deepen modules (move complexity behind simple interfaces)
- [ ] Apply SOLID principles where natural
- [ ] Consider what new code reveals about existing code
- [ ] Run tests after each refactor step

**Never refactor while RED.** Get to GREEN first.

## Stack-Specific Patterns

### TypeScript / Node.js

- **Runner**: Jest or Vitest — prefer Vitest for new projects (faster, native ESM)
- **Async**: use `async/await` in tests; wrap with `it("...", async () => { ... })`
- **Mocking at boundaries**: `jest.mock()`/`vi.mock()` for external modules; use DI for internal seams
- **Avoid**: `jest.spyOn` on internal collaborators — that's implementation coupling

### React

- **Library**: React Testing Library (RTL) — never Enzyme
- **Core rule**: query by what users see (`screen.getByRole`, `screen.getByText`), not by component name or test IDs
- **Interactions**: use `userEvent` from `@testing-library/user-event`, not `fireEvent`
- **What to test**: user-facing behavior ("clicking submit shows confirmation"), not props or state
- **Async**: wrap async state updates in `await waitFor(() => ...)`

### Python

- **Runner**: pytest
- **Fixtures**: use `@pytest.fixture` for shared setup; prefer function-scoped fixtures to avoid test coupling
- **Mocking at boundaries**: `unittest.mock.patch` or `pytest-mock`'s `mocker.patch` — at system boundaries only
- **Avoid**: patching internal functions; restructure with DI instead

### Java

- **Runner**: JUnit 5 (`@Test`, `@BeforeEach`)
- **Spring**: use `@SpringBootTest` for integration tests; avoid mocking Spring beans unless at a true external boundary
- **Mocking at boundaries**: Mockito — `@Mock` + `@InjectMocks` for unit tests at external seams only
- **Async**: use `CompletableFuture` or `Awaitility` for async assertions

## Checklist Per Cycle

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
```
