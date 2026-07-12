# AGENTS.md

## Project Context

Finger Fate is a SwiftUI iOS app by Sunstone Studio. The product is a finger chooser app in the same category as Chooser, Chooser!, Chwazi, and similar party/decision apps.

The core experience should let a group place fingers on the device screen, then fairly choose one or more people. Future work should preserve that expectation: fast setup, clear feedback, playful but simple visuals, and reliable multi-touch behavior.

## Repository Layout

- `Finger Fate/ContentView.swift`: main SwiftUI entry view for the app experience.
- `Finger Fate/Finger_FateApp.swift`: app entry point.
- `Finger Fate/Assets.xcassets`: app assets and colors.
- `Finger FateTests`: unit tests.
- `Finger FateUITests`: UI tests.

## Engineering Notes

- This is an Apple platform project. Prefer Xcode project tooling for builds, diagnostics, and UI test validation.
- Follow SwiftUI patterns and keep views small enough to reason about.
- Use Swift concurrency APIs where needed. Avoid introducing Combine unless the project already has a clear need for it.
- Keep naming idiomatic Swift: PascalCase types, camelCase properties and methods.
- Use `@State private var` for local SwiftUI state and `let` for constants.
- Avoid force unwraps unless the surrounding code proves the value is always present.

## Product Direction

- The app should feel immediate and touch-first. Avoid flows that require setup before the user can start choosing.
- Prioritize accurate, responsive multi-touch handling over decorative UI.
- Keep visual feedback understandable at a glance: fingers detected, choosing in progress, winner selected, and reset/new round.
- Make the interface suitable for quick use in social settings, with large targets and minimal text.

## Change Guidelines

- Limit edits to the requested task.
- Preserve existing project structure unless there is a concrete reason to change it.
- Add focused tests when behavior changes, especially chooser logic, random selection rules, multi-touch state, or reset behavior.
- If a feature depends on current Apple APIs, check current Apple documentation before assuming older SwiftUI/UIKit behavior.
