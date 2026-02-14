# Benchmark-First Setup Task

You are executing the `/setup-benchmarks` skill to establish testing infrastructure early in the project lifecycle.

## Philosophy

From "How to Get Out of Your Agent's Way":
> "Benchmarks should exist as early as possible. They are how you answer: Is this agent output actually good? Is it better than alternatives?"

Without benchmarks:
- You optimize based on intuition
- You mistake novelty for progress
- You ship something that feels impressive but performs poorly

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
   - Create `TESTING.md` document
   - Define what "good" looks like
   - Set coverage thresholds
   - Document benchmark targets

## Output Structure

After setup, the project should have:

```
project/
├── tests/               # Unit/integration tests
│   └── test_example.*   # Example test file
├── benchmarks/          # Performance benchmarks
│   └── bench_*.* # Example benchmark
├── TESTING.md           # Testing guidelines
├── .github/workflows/   # CI configuration (if applicable)
└── [config files]       # pytest.ini, jest.config.js, etc.
```

## Acceptance Criteria

- Tests can be run with a single command
- Example tests are present and passing
- Documentation explains how to add new tests
- Benchmarks are runnable and documented
- CI/CD is configured (or instructions provided)
- Quality standards are clearly defined

## Constraints

- Keep it simple - don't over-engineer
- Tests should be fast to run
- Examples should be realistic, not trivial
- Documentation should be concise
- Follow project conventions if they exist

## Process

1. Analyze current working directory
2. Detect project type and existing infrastructure
3. Ask user for preferences if needed
4. Create test/benchmark structure
5. Generate example files
6. Configure CI if appropriate
7. Create documentation
8. Run tests to verify setup

Execute the benchmark setup now.
