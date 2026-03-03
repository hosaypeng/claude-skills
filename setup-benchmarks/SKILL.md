---
name: setup-benchmarks
description: "Scaffold testing and benchmark infrastructure for a project. Use when user says 'set up tests', 'add benchmarks', 'create test suite', 'initialize CI', or when starting a new project that needs test/benchmark scaffolding."
user-invocable: true
---

# Benchmark-First Setup Task

## Objectives

Create representative, repeatable benchmarks that enable quality measurement from the start.

## What to Do

1. **Detect Project Type**:
   - Scan the working directory
   - Identify language/framework (Python, Node.js, Go, etc.)
   - Check for existing test infrastructure

2. **Scaffold Appropriate Tests**:

   **For Python projects**:
   - Create `tests/` directory
   - Add `pytest.ini` or `pyproject.toml` test config
   - Create example test file with basic assertions
   - Add `requirements-dev.txt` with pytest

   **For Node.js projects**:
   - Add test script to `package.json`
   - Create `tests/` or `__tests__/` directory
   - Add example test with jest/vitest/mocha
   - Include coverage configuration

   **For Go projects**:
   - Create `*_test.go` files alongside source
   - Add example table-driven tests
   - Configure coverage output

   **For other/unknown**:
   - Ask user what framework they prefer
   - Create generic test structure

3. **Create Benchmark Suite**:
   - Add `benchmarks/` directory
   - Create example benchmark for critical operations
   - Document how to run benchmarks
   - Set baseline metrics

4. **Set Up CI/CD Early**:
   - Create `.github/workflows/test.yml` (if GitHub)
   - Configure test runs on push/PR
   - Add coverage reporting
   - Set quality gates

5. **Define Acceptance Criteria**:
   - Add testing guidelines as comments in the test config file (e.g., top of `pytest.ini`, `jest.config.js`, or equivalent)
   - Define coverage thresholds in the test runner config
   - Document benchmark targets as comments in the benchmark files themselves
   - NEVER create `TESTING.md` or other standalone documentation files unless the user explicitly requests one

## Output Structure

After setup, the project should have:

```
project/
├── tests/               # Unit/integration tests
│   └── test_example.*   # Example test file
├── benchmarks/          # Performance benchmarks
│   └── bench_*.*        # Example benchmark (with targets in header comments)
├── .github/workflows/   # CI configuration (if applicable)
└── [config files]       # pytest.ini, jest.config.js, etc. (with testing guidelines in comments)
```

## Acceptance Criteria

- Tests can be run with a single command
- Example tests are present and passing
- Config file comments explain how to add new tests
- Benchmarks are runnable and documented
- CI/CD is configured (or instructions provided)
- Quality standards are clearly defined

## Constraints

- Prefer minimal configuration over comprehensive scaffolding.
- Tests should be fast to run
- Write example tests that exercise real project functions, not just assert(true).
- Documentation should be concise
- Follow project conventions if they exist

## Process

1. Analyze current working directory
2. Detect project type and existing infrastructure
3. Ask user for preferences if needed
4. Create test/benchmark structure
5. Generate example files
6. Configure CI if appropriate
7. Add inline documentation as comments in config and benchmark files (never create standalone .md docs)
8. Run tests to verify setup

## Troubleshooting

**Error: Unknown or undetectable project type**
Cause: No recognizable config files (`package.json`, `pyproject.toml`, `go.mod`, etc.) in the working directory.
Fix: Ask the user what language and test framework they want. Fall back to a generic test structure with shell-based test runners.

**Error: Existing test config conflicts with scaffolded config**
Cause: The project already has a `jest.config.js`, `pytest.ini`, or similar that contradicts the new setup.
Fix: Read existing configs first. Extend or merge with what's already there instead of overwriting. If conflicts are irreconcilable, ask the user which config to keep.

**Error: Scaffolded tests fail on first run**
Cause: Missing dev dependencies, wrong test runner version, or example tests reference non-existent code.
Fix: Install dev dependencies first (`npm install --save-dev`, `pip install -r requirements-dev.txt`). Ensure example tests only assert trivially true conditions until real code exists.

Execute the benchmark setup now.
