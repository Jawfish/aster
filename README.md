# Aster

Cross-language lint rules for testing best practices. Enforces behavior-driven testing patterns and discourages mocking in TypeScript and Python codebases.

> **Note:** This is a highly opinionated tool built for my personal workflow. The rules reflect my
> own philosophy and may not align with yours. Feel free to use it, fork it, or take inspiration from
> it.

## Installation

Requires [ast-grep](https://ast-grep.github.io/) and [jq](https://jqlang.github.io/jq/).

```bash
# Clone the repo
git clone https://github.com/Jawfish/aster.git

# Add to PATH (or symlink bin/aster somewhere in your PATH)
export PATH="$PATH:/path/to/aster/bin"
```

## Usage

```bash
# Full lint on a directory
aster lint ~/code/myproject
aster lint .

# Check only changed code (useful for CI/pre-commit)
aster diff              # Unstaged changes
aster diff main         # Changes vs main branch
aster staged            # Staged changes only

# Test the rules
aster test
```

## Example Output

### Python

```python
from unittest.mock import patch

def fetch_user(id):
    pass

def test_fetch_user_should_return_data():
    assert x == 1
```

```
error[no-mocks-py]: Mocking creates brittle tests that verify implementation rather than behavior.

Our testing philosophy:
- Focus on behavior, not implementation details
- Use state-based testing over interaction-based testing
- Tests should verify what the code does, not how it does it
- Prefer dependency injection with test doubles over mocking

Why mocking is problematic:
- Tests break when you refactor, even if behavior is unchanged
- Mocks test a simulation, not the actual code that runs in production
- Mock configurations must be updated across many tests when dependencies change
- Complex mock setup obscures what's actually being tested

Instead of mocking:
1. Extract pure logic into separate functions that don't need mocking
2. Use constructor injection or factory methods to provide test implementations
3. Create "nullable" versions of infrastructure classes with controllable behavior

Example refactoring:
  # Before: Mocking with patch
  @patch('mymodule.api_client')
  def test_fetch_user(mock_client):
      mock_client.get.return_value = {'name': 'Alice'}
      result = fetch_user(123)
      mock_client.get.assert_called_with('/users/123')

  # After: Dependency injection with fake
  def test_fetch_user():
      fake_client = FakeApiClient(responses={'/users/123': {'name': 'Alice'}})
      service = UserService(client=fake_client)
      result = service.fetch_user(123)
      assert result.name == 'Alice'

See testing guidelines for more details on behavior-driven testing.

  ┌─ test_example.py:1:1
  │
1 │ from unittest.mock import patch
  │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

```
error[no-test-name-with-method-names-py]: Test names should describe behavior, not reference implementation methods.

Our test naming philosophy:
- Focus on what the system does, not how it's tested
- Use plain English that non-programmers can understand
- Follow the ACE framework: Action, Condition, Expectation
- Tests document behavior, not code structure

Why avoid method names in tests:
- Tests coupled to method names break when you refactor
- Method names are implementation details, not user behavior
- Tests should survive renaming and restructuring
- Behavior is what matters, not the specific function name

Example refactoring:
  # Before: References method name (starts with verb)
  def test_calculate_damage_returns_correct_value():
  def test_get_user_by_id_fetches_from_database():

  # After: Describes behavior (starts with noun/subject)
  def test_damage_is_attack_power_minus_defense():
  def test_user_is_fetched_by_unique_identifier():

See testing guidelines for more details and examples.

  ┌─ test_example.py:6:1
  │
6 │ def test_fetch_user_should_return_data():
  │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

```
error[no-test-name-with-should-py]: Test names should state facts, not wishes or expectations using "should".

Our test naming philosophy:
- A test is an atomic fact about system behavior
- Tests are specifications, not aspirations
- Use declarative language that states what IS, not what SHOULD BE
- Tests document actual behavior with confidence

Why avoid "should":
- "Should" sounds aspirational or uncertain
- Tests verify facts, not hypotheticals
- Weakens the authority of tests as specifications
- Creates distance between test and the behavior it verifies

Example refactoring:
  # Before: Aspirational language
  def test_player_should_respawn_at_checkpoint():
  def test_game_should_pause_when_window_loses_focus():

  # After: Factual language
  def test_player_respawns_at_checkpoint():
  def test_game_pauses_when_window_loses_focus():

This is a simple but important distinction - your tests are executable specifications
of how the system behaves, not suggestions for how it might behave.

  ┌─ test_example.py:6:1
  │
6 │ def test_fetch_user_should_return_data():
  │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

```
error[assert-with-message-py]: Assertions without messages make test failures cryptic and waste debugging time.

Our testing philosophy:
- Every assertion should explain what was being verified
- Test failures should be self-documenting
- Fail fast with clear, actionable information
- A failing test should explain the problem without reading test code

Why this matters:
- "AssertionError" alone requires reading source code to understand the failure
- CI logs with bare assertions are nearly useless for diagnosis
- Good assertion messages reduce debugging time from hours to seconds
- Messages serve as documentation for what the test is actually checking

What makes a good assertion message:
1. State what was expected vs what was received
2. Include relevant variable values or context
3. Describe the condition being verified in plain English
4. Be specific enough to locate the issue without reading code

Example refactoring:
  # Before: No context
  assert result == expected
  assert user is not None

  # After: Self-documenting failures
  assert result == expected, f"Expected {expected}, got {result}"
  assert user is not None, f"User {user_id} not found in database"
  assert response.status_code == 200, f"API returned {response.status_code}: {response.text}"

  ┌─ test_example.py:7:5
  │
7 │     assert x == 1
  │     ^^^^^^^^^^^^^
```

### TypeScript

```typescript
test("should return user data", async () => {
  const mockFetch = vi.fn();
  expect(mockFetch).toHaveBeenCalled();
});
```

```
error[no-mocks]: Mocking creates brittle tests that verify implementation rather than behavior.

Our testing philosophy:
- Focus on behavior, not implementation details
- Use state-based testing over interaction-based testing
- Tests should verify what the code does, not how it does it
- Prefer dependency injection with test doubles over mocking

Why mocking is problematic:
- Tests break when you refactor, even if behavior is unchanged
- Mocks test a simulation, not the actual code that runs in production
- Mock configurations must be updated across many tests when dependencies change
- Complex mock setup obscures what's actually being tested

Instead of mocking:
1. Extract pure logic into separate functions that don't need mocking
2. Use constructor injection or factory methods to provide test implementations
3. Create "nullable" versions of infrastructure classes with controllable behavior

Example refactoring:
  // Before: Mocking a module
  vi.mock('./api', () => ({ fetchUser: vi.fn() }))

  // After: Dependency injection
  class UserService {
    constructor(private api: ApiClient) {}
    static createNull(responses = {}) {
      return new UserService(new FakeApiClient(responses));
    }
  }

See testing guidelines for more details on behavior-driven testing.

  ┌─ example.test.ts:2:21
  │
2 │   const mockFetch = vi.fn();
  │                     ^^^^^^^
```

```
error[no-test-name-with-should]: Test names should state facts, not wishes or expectations using "should".

Our test naming philosophy:
- A test is an atomic fact about system behavior
- Tests are specifications, not aspirations
- Use declarative language that states what IS, not what SHOULD BE
- Tests document actual behavior with confidence

Why avoid "should":
- "Should" sounds aspirational or uncertain
- Tests verify facts, not hypotheticals
- Weakens the authority of tests as specifications
- Creates distance between test and the behavior it verifies

Example refactoring:
  // Before: Aspirational language
  test("player should respawn at checkpoint")
  test("game should pause when window loses focus")
  test("damage should not exceed max health")

  // After: Factual language
  test("player respawns at checkpoint")
  test("game pauses when window loses focus")
  test("damage does not exceed max health")

This is a simple but important distinction - your tests are executable specifications
of how the system behaves, not suggestions for how it might behave.

  ┌─ example.test.ts:1:1
  │
1 │ test("should return user data", async () => {
  │ ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
```

## Rules

### ast-grep Rules

| Rule                              | Description                                           |
| --------------------------------- | ----------------------------------------------------- |
| `no-mocks`                        | Detects vi.mock, jest.mock, sinon, patch, monkeypatch |
| `no-interaction-assertions`       | Detects toHaveBeenCalled, assert_called, etc.         |
| `no-test-name-with-should`        | Tests state facts, not wishes                         |
| `no-test-name-with-method-names`  | Tests describe behavior, not implementation           |
| `no-misleading-test-double-names` | Variables named "mock\*" imply mocking                |
| `assert-with-message`             | Errors and assertions need messages                   |

### SUT Name Check

Detects test names that reference implementation symbols (function/class names). Tests should describe behavior, not implementation details.

## Contributing

### Setup

Install git hooks after cloning:

```bash
just init
```

This installs:

- **pre-commit**: Runs linters (yamlfmt, shfmt, shellcheck, actionlint)
- **pre-push**: Runs tests (ast-grep rules, SUT check)

### Commands

```bash
just ci              # Run all linters
just test            # Run ast-grep rule tests
just lint-yaml       # Check YAML formatting
just lint-scripts    # Check shell scripts (shfmt + shellcheck)
just lint-actions    # Lint GitHub Actions workflows
just fmt-yaml        # Format YAML files
just fmt-scripts     # Format shell scripts
just act             # Run CI locally with act
```

### Requirements

- [ast-grep](https://ast-grep.github.io/)
- [jq](https://jqlang.github.io/jq/)
- [yamlfmt](https://github.com/google/yamlfmt)
- [shfmt](https://github.com/mvdan/sh)
- [shellcheck](https://www.shellcheck.net/)
- [actionlint](https://github.com/rhysd/actionlint)

## License

MIT
