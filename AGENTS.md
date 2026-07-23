# AGENTS.md

## Project Context

Finger Fate is a SwiftUI iOS app by Sunstone Studio. The product is a finger chooser app in the same category as Chooser, Chooser!, Chwazi, and similar party/decision apps.

The core experience should let a group place fingers on the device screen, then fairly choose one or more people. Future work should preserve that expectation: fast setup, clear feedback, playful but simple visuals, and reliable multi-touch behavior.

## Repository Layout

- `Finger Fate/ContentView.swift`: main SwiftUI entry view for the app experience.
- `Finger Fate/Finger_FateApp.swift`: app entry point.
- `Finger Fate/Assets.xcassets`: app assets and colors.
- `Finger FateTests`: unit tests (Swift Testing).
- `Finger FateUITests`: UI tests.

## Product Direction

- Feel immediate and touch-first. No setup flow before the user can start choosing.
- Prioritize accurate, responsive multi-touch over decorative UI.
- Visual feedback must be clear at a glance: fingers detected, choosing in progress, winner selected, reset/new round.
- Suitable for quick social use: large targets, minimal text.

## Engineering Notes

- Apple platform project. Prefer Xcode for builds, diagnostics, and UI test validation.
- Prefer Swift concurrency (`async`/`await`, `Task`, actors) over Combine unless Combine is already established for a clear need.
- If a feature depends on current Apple APIs, check current Apple documentation before assuming older SwiftUI/UIKit behavior.

## Swift Style

### Naming

- Types: `PascalCase`. Properties, methods, and locals: `camelCase`.
- Booleans read as predicates: `isChoosing`, `hasWinner`, `canReset`.
- Functions read as verbs: `selectWinners`, `resetRound`, `touchPoints(for:)`.
- Prefer domain language (`winnerCount`, `activeTouches`) over generic names (`data`, `items`, `temp`).
- Scope sets length: short names are fine in a tight local scope; longer names when the value crosses functions.

### Immutability and mutation

Prefer values that do not change. Mutation is allowed when it is the idiomatic Swift/SwiftUI tool—not as a default habit.

- Prefer `let` over `var`. Introduce `var` only when reassignment is required.
- Prefer value types (`struct`, `enum`) for models and state snapshots. Use `class` only when shared mutable identity is required (rare in this app).
- Prefer transforming data into new values (`map`, `filter`, `compactMap`, `reduce`, or pure functions that return a new model) over in-place mutation of shared state.
- Pure selection and game logic should take inputs and return outputs with no side effects—easy to unit test.
- **Idiomatic mutation (use freely when it fits):**
  - SwiftUI state: updating `@State`, `@Binding`, `@StateObject` / `@Observable` is how the UI works.
  - `mutating` methods on value types when the type owns a coherent local change.
  - Building a local collection with `var` + `append` when `map`/`filter` would be less clear.
- **Avoid:** long-lived mutable reference objects for chooser state; hidden mutation of globals/singletons; force-mutating collections when a new array/set expresses intent better.

### Control flow and structure

- Prefer `guard` / early `return` for preconditions over deep nesting.
- Prefer `if let` / `guard let` / `switch` over force unwraps and nested conditionals.
- Prefer exhaustive `switch` on enums over stringly-typed or boolean flag piles.
- Keep functions small and single-purpose. Extract chooser rules, random selection, and touch bookkeeping out of views when they grow past presentation.
- Default to `private` for types, properties, and helpers that are not part of a module API.

### Optionals and safety

- Avoid force unwraps (`!`) unless the surrounding code proves the value is always present (and a crash is preferable to continuing incorrectly).
- Prefer `??`, optional chaining, `guard let`, and `Result` / throws for failure paths.
- Never use empty `catch` or silently ignore failures in touch, selection, or reset paths.

### Comments

- No file, type, or method header comment blocks. Names and types carry the contract.
- Comment only non-obvious rules: fairness invariants, timing edge cases, multi-touch quirks, or workarounds (link the issue when relevant).
- No narration comments (`// loop over touches`). Prefer clearer names and smaller functions.
- Budget: most files need zero comment lines. More than a couple usually means the code should be clearer instead.

## SwiftUI Patterns

- Keep views small and declarative. `body` composes UI; heavy logic belongs in pure functions, small model types, or testable helpers.
- Local UI state: `@State private var`. Prefer `let` for values that never change for the life of the view.
- Prefer value-type models driven by state over sprawling view-local `var` bags.
- Prefer composition (small child views, modifiers) over one large view with many branches.
- Prefer the system multi-touch / gesture APIs appropriate to the deployment target; do not reimplement touch tracking unless necessary.
- Animations and feedback should clarify state transitions (detected → choosing → winner → reset), not obscure them.

## Testing

- During development, run only unit tests: `xcodebuild test -scheme "Finger Fate" -destination 'platform=iOS Simulator,name=iPhone 17'` uses the default `UnitTests.xctestplan`, which excludes the slow UI tests.
- Do not run the UI tests locally unless explicitly asked; CI runs the full suite via `-testPlan AllTests` on every PR.
- Use Swift Testing (`import Testing`, `@Test`, `#expect`) in `Finger FateTests`.
- Assert observable behavior (inputs → outputs): selection fairness constraints, winner counts, reset clearing state, edge cases (0 / 1 / many touches).
- Name tests after the behavior: `selectsExactlyRequestedWinnerCount`, `resetClearsActiveTouches`.
- Prefer testing pure logic without spinning up full view hierarchies when possible.
- Add focused tests when chooser logic, random selection rules, multi-touch state, or reset behavior changes.

## Change Guidelines

- Smallest change that solves the task. Leave unrelated code untouched.
- Match existing project structure and naming unless there is a concrete reason to change them.
- When editing existing code, raise it to these standards only in the lines you touch—do not drive-by reformat the file.
- Prefer Xcode project tooling for build and test validation before calling work done.
- Do not invent architecture (coordinators, service layers, DI containers) unless the feature clearly needs a new seam.
