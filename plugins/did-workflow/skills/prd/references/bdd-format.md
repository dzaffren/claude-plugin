# BDD Acceptance Criteria Format

When generating Gherkin-format acceptance criteria:

```gherkin
As a [user type],
I want to [action/capability]
So that [benefit/value]

Acceptance Criteria

Background:
  Given [common setup]
  And [data setup - use tables]
    | Column1 | Column2 |
    | value1  | value2  |

Scenario: [Descriptive name]
  Given [precondition]
    And [additional precondition]
  When [action]
    And [additional action]
  Then [expected outcome]
    And [additional outcome]

Scenario Outline: [Descriptive name for a group of similar cases]
  Given [precondition with <variable>]
  When [action with <input>]
  Then [expected outcome with <expected>]

  Examples:
    | variable | input  | expected |
    | value1   | inputA | outcome1 |
    | value2   | inputB | outcome2 |
```

### Rules

- **One keyword pair per block** — each scenario step block uses exactly one `Given`, one `When`, and one `Then`. Use `And` for additional lines within the same block. Never write consecutive `Given`/`Given`, `When`/`When`, or `Then`/`Then` lines.

  Bad:

  ```gherkin
  Given I am logged in
  Given I have items in my cart
  When I click checkout
  When I confirm the order
  Then I see a confirmation message
  Then I receive an email
  ```

  Good:

  ```gherkin
  Given I am logged in
    And I have items in my cart
  When I click checkout
    And I confirm the order
  Then I see a confirmation message
    And I receive an email
  ```

- **User perspective** — "I should see", "I click", not "API returns 200"
- **No technical jargon** — no "API", "database", "HTTP status", DB field names, or JSON field names
- **No implementation IDs** — use descriptive names ("Ahmad's registration", "the morning bus"), not system IDs ("reg-001", "sched-bus-001")
- **Use data tables** for lists of entities, expected results, setup data
- **Use Scenario Outline + Examples** when multiple scenarios differ only in input/expected values (e.g., several validation error cases with different invalid fields)
- **Include** happy paths, error scenarios, business rules
- **Exclude** implementation details, deployment, code-level validation
- **No UI component descriptions** — Don't describe styling, colors, sizes, borders, icons, or visual design in scenarios. `Then an "Add" button is displayed` is correct; `Then the button has a 1.5px dashed border in #d0d0d0` is not. UI design details belong in the UI/Frontend Requirements section.
- **Key Scenarios vs Test Scenarios** — Key Scenarios describe _behavior_ from the user's point of view. The Test Scenarios section later in the spec is where implementation-level detail (DB fields, API endpoints, specific IDs, error codes) belongs.
