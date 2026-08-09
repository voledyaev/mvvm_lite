# Contributing

The surface area is the feature. `mvvm_lite` is deliberately small and will
stay that way — a pull request that adds an API needs to argue why the pattern
can't live in the application layer instead.

## Setup

```bash
flutter pub get
```

The floor in `pubspec.yaml` (currently Dart 3.8, which is Flutter 3.32) applies
to development and to consumers alike, and CI verifies it in a separate job that
runs the suite on exactly that Flutter release.

The floor is set as low as the repository can still verify: Dart 3.8 is where
`flutter_lints` resolves and where everything here compiles and formats without
change. Only `sdk:` is declared — a `flutter:` constraint alongside it adds a
second number that can silently contradict the first, since the Dart version is
determined by the Flutter release anyway.

## Before opening a PR

```bash
dart format lib test example/lib example/test
flutter analyze
flutter test
(cd example && flutter test)
dart pub publish --dry-run
```

CI runs exactly these, plus `pana` to guard the pub.dev score.

## Conventions

- Every public member carries a doc comment (`public_member_api_docs` is on).
- Behavior changes come with a test that fails without them.
- Errors that a user can trigger throw a descriptive `FlutterError` in release
  builds too — not a debug-only `assert`.
- `CHANGELOG.md` gets an entry in the same commit as the change.
