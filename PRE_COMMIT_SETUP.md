# Pre-Commit Hook Setup

This repository uses Git pre-commit hooks to ensure code quality before commits.

## What Gets Checked

The pre-commit hook runs automatically before every commit and performs:

1. **SwiftFormat** - Automatic code formatting
2. **SwiftLint** - Code quality and style linting
3. **Tests** - Full test suite execution
4. **Build** - Build verification

## Installation

### Prerequisites

Install the required tools via Homebrew:

```bash
brew install swiftformat swiftlint
```

### Hook Installation

The pre-commit hook is already configured at `.git/hooks/pre-commit`. If you need to reinstall it:

```bash
chmod +x .git/hooks/pre-commit
```

## Configuration Files

### `.swiftformat`

SwiftFormat configuration for consistent code style:
- Swift 6.0 compatible
- 4-space indentation
- 120 character line width
- Sorted imports
- Redundant code removal

### `.swiftlint.yml`

SwiftLint rules for code quality:
- Opt-in rules for best practices
- Custom rule thresholds
- Excluded directories (.build, Mocks)
- Force unwrapping warnings

## What Happens During Commit

```
🔍 Running pre-commit checks...
📝 Found Swift files to check
🎨 Running SwiftFormat...
✅ SwiftFormat passed
🔬 Running SwiftLint...
✅ SwiftLint passed
🧪 Running tests...
✅ All tests passed
🏗️  Verifying build...
✅ Build successful
✨ All pre-commit checks passed!
```

## If Checks Fail

### SwiftFormat Failed
SwiftFormat automatically fixes formatting issues and stages the changes. You won't see this fail unless there's a syntax error.

### SwiftLint Failed
```bash
❌ SwiftLint found issues
Run 'swiftlint lint' to see details
```

Fix the reported issues and try committing again.

### Tests Failed
```bash
❌ Tests failed
Run 'swift test' to see details
```

Fix the failing tests before committing.

### Build Failed
```bash
⚠️  Build has warnings or errors
Run 'swift build' to see details
```

The hook only warns on build issues but doesn't block commits. However, you should fix build errors before committing.

## Running Checks Manually

### Format Code
```bash
swiftformat .
```

### Lint Code
```bash
swiftlint lint
```

### Run Tests
```bash
swift test
```

### Build
```bash
swift build
```

## Bypassing the Hook (Emergency Only)

⚠️ **Not recommended** - Only use in emergencies:

```bash
git commit --no-verify -m "emergency fix"
```

## Customizing

### SwiftFormat Rules

Edit `.swiftformat` to change formatting rules:

```bash
# See all available options
swiftformat --help options

# Test formatting without changing files
swiftformat --lint .
```

### SwiftLint Rules

Edit `.swiftlint.yml` to modify linting rules:

```bash
# See all available rules
swiftlint rules

# Run with different severity
swiftlint lint --strict
```

## CI/CD Integration

These same tools run in GitHub Actions (`.github/workflows/tests.yml`):
- SwiftFormat check (lint mode, no changes)
- SwiftLint
- Test suite with coverage
- Build verification

The pre-commit hook ensures your code will pass CI before you push.

## Troubleshooting

### Hook Not Running

Check if it's executable:
```bash
ls -la .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### SwiftFormat/SwiftLint Not Found

Install the tools:
```bash
brew install swiftformat swiftlint
```

Verify installation:
```bash
which swiftformat
which swiftlint
```

### Tests Taking Too Long

The hook runs the full test suite. If it's too slow, consider:
- Running only fast unit tests in the hook
- Moving integration tests to CI only
- Optimizing slow tests

Edit `.git/hooks/pre-commit` to change test behavior.

### Conflicts with IDE Formatting

If your IDE (Xcode, VSCode) has different formatting:
1. Configure your IDE to use `.swiftformat` settings
2. Or disable IDE auto-formatting
3. Let SwiftFormat handle all formatting

## Best Practices

1. **Run checks before staging**: Format and lint while developing
2. **Fix issues immediately**: Don't accumulate linting issues
3. **Keep tests fast**: Pre-commit should be quick
4. **Update rules carefully**: Coordinate formatting changes with team
5. **Don't bypass hooks**: They exist for good reasons

## Resources

- [SwiftFormat Documentation](https://github.com/nicklockwood/SwiftFormat)
- [SwiftLint Documentation](https://github.com/realm/SwiftLint)
- [Git Hooks Documentation](https://git-scm.com/docs/githooks)
