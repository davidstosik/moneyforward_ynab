# CLAUDE.md - AI Assistant Guide for MFYNAB

## Project Overview

**MFYNAB** (MoneyForward to YNAB) is a Ruby gem that synchronizes transaction history from MoneyForward (Japanese financial management service) to YNAB (You Need A Budget).

**Key Facts:**
- **Language:** Ruby 3.3.0+ required
- **Current Version:** 0.3.0
- **Repository:** https://github.com/davidstosik/moneyforward_ynab
- **License:** MIT
- **Author:** David Stosik

### How It Works

1. Uses Ferrum (headless Chrome) to log into MoneyForward and obtain session cookies
2. Makes authenticated HTTP requests to download transaction CSV files
3. Parses CSV data and converts it to YNAB-compatible format
4. Uses the YNAB API Ruby library to upload transactions to YNAB budgets
5. Account mappings are configured via YAML files

## Architecture & Directory Structure

```
mfynab/
├── bin/                    # Development executables (rake, rubocop)
├── exe/                    # Published executable (mfynab CLI)
├── lib/mfynab/            # Main source code
│   ├── cli.rb             # CLI entry point and orchestration
│   ├── config.rb          # Configuration management
│   ├── credentials_normalizer.rb  # Credential loading logic
│   ├── money_forward.rb   # MoneyForward API client
│   ├── money_forward/
│   │   ├── session.rb     # Session management and authentication
│   │   └── account_status.rb  # Account status checking/updating
│   ├── money_forward_data.rb  # CSV parsing and data structures
│   ├── ynab_transaction_importer.rb  # YNAB API integration
│   └── version.rb         # Version constant
├── test/                  # Minitest test suite
│   ├── test_helper.rb    # Test configuration
│   ├── mfynab/           # Tests mirroring lib/ structure
│   └── support/          # Test helpers and fixtures
├── config/               # Example configuration files
├── .rubocop.yml          # RuboCop linting configuration
└── .github/workflows/    # CI/CD workflows
```

## Key Components

### CLI (`lib/mfynab/cli.rb`)

The main orchestrator that:
- Parses command line arguments (expects a config file path)
- Initializes all components (config, session, money_forward, ynab_importer)
- Coordinates the sync workflow:
  1. Update MoneyForward accounts
  2. Fetch transaction data
  3. Import to YNAB

**Important:** Logger is passed to nearly all components for debugging.

### Config (`lib/mfynab/config.rb`)

Manages configuration from YAML files. Key features:
- **Backwards compatibility:** Supports old config files with top-level keys (deprecated)
- **Default values:** `months_to_sync` defaults to 3
- **Credential normalization:** Delegates to `CredentialsNormalizer`

### CredentialsNormalizer (`lib/mfynab/credentials_normalizer.rb`)

Handles flexible credential loading:
- **Plain text:** Credentials directly in YAML
- **Environment variables:** Using `type: "env"` with `value: "ENV_VAR_NAME"`
- **Backwards compatible:** Falls back to ENV vars if credentials section missing

### MoneyForward::Session (`lib/mfynab/money_forward/session.rb`)

Authentication and HTTP communication:
- Uses Ferrum to log in via headless Chrome
- Stores `_moneybook_session` cookie for authenticated requests
- Provides `http_get` and `http_post` methods for API calls
- Extracts CSRF tokens when needed
- **Error handling:** Takes screenshots on failure (saved as `screenshot.png`)

**Important environment variable:**
- `NO_HEADLESS`: Set to run Chrome in non-headless mode for debugging

### MoneyForward (`lib/mfynab/money_forward.rb`)

Main interface to MoneyForward:
- `update_accounts`: Ensures accounts are refreshed before syncing
- `fetch_data`: Downloads CSV files for specified months
- `download_csv`: Fetches monthly CSV data
- Uses polling with `sleep(5)` to wait for account updates (marked as FIXME)

**Important:** CSV encoding is Shift-JIS, converted to UTF-8.

### MoneyForwardData (`lib/mfynab/money_forward_data.rb`)

Parses MoneyForward CSV files:
- Defines header mappings from Japanese to English keys
- Converts CSV headers using `csv_header_converters`
- Groups transactions by account

**CSV Header Mappings:**
```ruby
{
  include: "計算対象",
  date: "日付",
  content: "内容",
  amount: "金額（円）",
  account: "保有金融機関",
  category: "大項目",
  subcategory: "中項目",
  memo: "メモ",
  transfer: "振替",
  id: "ID",
}
```

### YnabTransactionImporter (`lib/mfynab/ynab_transaction_importer.rb`)

YNAB API integration:
- Converts MoneyForward transactions to YNAB format
- Handles duplicate detection via `import_id`
- Respects YNAB field length limits:
  - `MEMO_MAX_LENGTH = 500`
  - `PAYEE_MAX_LENGTH = 200`
  - `IMPORT_ID_MAX_LENGTH = 36`

**Critical:** The `generate_import_id_for` method is crucial for preventing duplicates. DO NOT modify without careful consideration. The import_id format is `MFBY:v1:` + transaction ID (or hashed if too long).

**Amount conversion:** MoneyForward amounts are in yen (¥), YNAB expects milliunits (multiply by 1000).

## Development Workflow

### Setup

```bash
# Clone and install dependencies
git clone <repo-url>
cd mfynab
bundle install
```

### Running Tests

```bash
# Run all tests (default rake task)
bin/rake test

# Or directly
bundle exec rake test
```

**Test framework:** Minitest with WebMock for HTTP stubbing.

### Linting

```bash
# Run RuboCop
bin/rubocop

# Auto-fix issues where possible
bin/rubocop -a
```

### Running Locally

```bash
# Create a config file (see config/example.yml)
# Set environment variables or use dotenv
bundle exec exe/mfynab path/to/config.yml

# Debug mode
DEBUG=1 bundle exec exe/mfynab path/to/config.yml
```

### Building and Testing the Gem

```bash
# Build gem
bundle exec rake build

# Install locally
gem install pkg/mfynab-0.3.0.gem

# Test installed gem
mfynab path/to/config.yml
```

## Code Conventions & Style Guide

### RuboCop Configuration (`.rubocop.yml`)

**Ruby Version:** 3.3+

**Key Style Rules:**
- **String literals:** Double quotes (`"string"`, not `'string'`)
- **Hash syntax:** Never use shorthand (`foo: bar`, not `:foo => bar` or shorthand syntax)
- **Trailing commas:** Required for multiline arrays, hashes, and arguments
- **Documentation:** Disabled (no class/module documentation required)
- **Memoization:** Leading underscores required (`@_variable ||= value`)
- **Indentation:** Indented internal methods

**Metrics Limits:**
- `AbcSize`: Max 18
- `MethodLength`: Max 20
- `ClassLength`: Max 150
- `ModuleLength`: Max 150

Tests are excluded from metrics checks.

### Code Patterns

#### 1. Memoization with Leading Underscores

```ruby
def config
  @_config ||= Config.from_yaml(config_file, logger)
end
```

All memoized instance variables MUST use a leading underscore.

#### 2. Logger Passing

The logger is passed explicitly to most classes via constructor:

```ruby
def initialize(username:, password:, logger:)
  @logger = logger
end
```

This is intentional (though noted as "feels weird" in README).

#### 3. Frozen String Literals

ALL Ruby files MUST start with:

```ruby
# frozen_string_literal: true
```

#### 4. Private Methods

Use `private` with indented methods:

```ruby
private

  attr_reader :foo, :bar

  def helper_method
    # ...
  end
```

## Testing

### Structure

Tests mirror the `lib/` directory structure:
- `test/mfynab/cli_test.rb` → `lib/mfynab/cli.rb`
- `test/mfynab/config_test.rb` → `lib/mfynab/config.rb`
- etc.

### Test Support Files

Located in `test/support/`:
- `fake_money_forward_app.rb` - Sinatra app for stubbing MoneyForward
- `money_forward_csv.rb` - CSV fixtures
- `test_loggers.rb` - Logger helpers
- `ynab_requests.rb` - YNAB API stubbing

### Running Specific Tests

```bash
# Single test file
ruby test/mfynab/config_test.rb

# With debug output
DEBUG=1 ruby test/mfynab/config_test.rb
```

## CI/CD

GitHub Actions workflow (`.github/workflows/ruby.yml`):

**Matrix:**
- Ruby versions: 3.3, 3.4
- Two jobs: `test` and `lint`

**Test job:** Runs `bin/rake` (tests)
**Lint job:** Runs `bin/rubocop`

Triggered on:
- Push to `main`
- Pull requests to `main`

## Important Notes & Gotchas

### 1. Import ID Generation (CRITICAL)

The `generate_import_id_for` method in `YnabTransactionImporter` is crucial:
- Format: `MFBY:v1:` + transaction ID
- Changing this will cause duplicate transactions in YNAB
- Scoped per account, not per budget
- Uses SHA256 hash if ID exceeds max length

**DO NOT modify without extensive testing.**

### 2. Backwards Compatibility

The codebase maintains backwards compatibility in several areas:
- Old config files with top-level keys
- Config files without credentials section (falls back to ENV vars)
- Import ID format (doesn't hash short IDs for compatibility)

When making changes, consider backwards compatibility or coordinate breaking changes with version bumps.

### 3. Known FIXMEs

Several areas marked for improvement:
- Using `sleep()` for polling account updates
- CSV files saved to disk unnecessarily
- Error handling could be improved
- CSRF token handling might not be truly session-scoped
- Could switch to Faraday for HTTP requests

### 4. Japanese Language Support

MoneyForward is a Japanese service:
- CSV headers are in Japanese
- Login confirmation checks for "ログアウト" (logout)
- Some category values like "未分類" (uncategorized) are filtered

Be careful when modifying string matching logic.

### 5. Security Considerations

**Credentials:**
- Never commit plain-text credentials
- Support for environment variables and 1Password CLI
- Be careful with logging (sensitive data)

**Session cookies:**
- Stored in memory, not persisted (yet - see roadmap)
- Expire after 30 days of inactivity per MoneyForward

### 6. Debugging

**Enable debug logging:**
```bash
DEBUG=1 mfynab config.yml
```

**Non-headless browser (see login process):**
```bash
NO_HEADLESS=1 mfynab config.yml
```

**Screenshot on error:**
Login failures automatically save `screenshot.png` in the current directory.

## Common Development Tasks

### Adding a New Configuration Option

1. Update `config/example.yml` with the new option
2. Add getter method in `lib/mfynab/config.rb`
3. Add default value if appropriate
4. Update relevant component to use the config option
5. Add tests in `test/mfynab/config_test.rb`
6. Update README.md if user-facing

### Adding a New MoneyForward API Call

1. Add method to `MoneyForward::Session` for the HTTP call
2. Add business logic to `MoneyForward` class
3. Add tests with WebMock stubs in `test/support/fake_money_forward_app.rb`
4. Consider encoding issues (Shift-JIS → UTF-8)

### Modifying Transaction Import Logic

**IMPORTANT:** Be extremely careful when modifying:
- `generate_import_id_for` - Can cause duplicate transactions
- `generate_memo_for` - Can affect existing transaction matching
- Amount conversion - Off by 1000× will break everything
- Date format conversion - YNAB expects `YYYY-MM-DD`

Always test thoroughly with a test YNAB budget.

### Adding Dependencies

1. Add to `mfynab.gemspec` (runtime deps) or `Gemfile` (dev deps)
2. Run `bundle install`
3. Update `Gemfile.lock`
4. Commit both files

### Releasing a New Version

1. Update `lib/mfynab/version.rb`
2. Update `CHANGELOG.md` with changes and commit SHAs
3. Run tests: `bin/rake test`
4. Run linting: `bin/rubocop`
5. Build gem: `bundle exec rake build`
6. Create git tag: `git tag v0.x.x`
7. Push: `git push && git push --tags`
8. Publish to RubyGems: `gem push pkg/mfynab-0.x.x.gem`

## Roadmap & Future Improvements

(From README.md - consider these when planning features)

### High Priority
- Deploy/automate: Docker + Kamal for scheduled runs
- Better session management: Cookie persistence, browser-based login fallback
- Handle CAPTCHA and additional authentication prompts

### Medium Priority
- Migrate CLI to Thor (better argument parsing)
- Implement `Transaction` model (extract logic from existing classes)
- Improve changelog workflow

### Low Priority
- Store config/credentials in `~/.config/`
- Keyring/OS-level secure storage for credentials
- Reusable test fixtures
- Investigate transaction count discrepancies

## Questions or Issues?

When encountering unclear code or ambiguous behavior:
1. Check for FIXME/TODO comments in the code
2. Look at test files for usage examples
3. Review recent commits in CHANGELOG.md
4. Check GitHub issues for context

## Version History

- **0.3.0** (2025-03-26): Credentials in config file, removed top-level config key requirement
- **0.2.0** (2025-03-25): Auto-refresh MoneyForward accounts, better account matching
- **0.1.4** (2024-08-25): Bug fixes for months_to_sync, improved logging

---

**Last Updated:** 2025-11-23
**For:** MFYNAB version 0.3.0
