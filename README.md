# MoneyForward to YNAB migrator

This Ruby script downloads transaction history from Money Forward then uploads
it to YNAB.

## Principle

- Use [Ferrum](https://github.com/rubycdp/ferrum) to browse to the Money Forward
  website, log in and save a session cookie.
- Craft HTTP requests to Money Forward including the session cookie above to
  retrieve transactions in CSV files.
- Parse the CSV files and convert the data to a format that works with YNAB.
- Use [YNAB API Ruby library](https://github.com/ynab/ynab-sdk-ruby) to post
  transactions to your YNAB budget.
- Budget and account mappings are set in a configuration file (see `config/example.yml`).

## Setup

You'll need Ruby 3.3.0 or above.

```sh
# Install gem
gem install mfynab

# Start a config YAML file
wget https://raw.githubusercontent.com/davidstosik/moneyforward_ynab/main/config/example.yml -O mfynab-david.yml
```

The script currently looks for credentials in environment variables:

- `MONEYFORWARD_USERNAME`
- `MONEYFORWARD_PASSWORD`
- `YNAB_ACCESS_TOKEN`

You can for example use [envchain](https://github.com/sorah/envchain) to manage
those credentials:

```sh
envchain --set --noecho mfynab_david MONEYFORWARD_USERNAME MONEYFORWARD_PASSWORD YNAB_ACCESS_TOKEN
```

## Running

To run, you'll simply need to set the environment variables.
Using `envchain`, that'll look like this:

```sh
envchain mfynab_david mfynab mfynab-david.yml
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bin/rake test` to run the tests.

## Todo

- Force MoneyForward to sync all accounts before downloading data. (Can take a while.)
- Use Thor to manage the CLI. (And/or TTY?)
- Implement `Transaction` model to extract some logic from existing classes.
- Handle the Amazon account differently (use account name as payee instead of content?)
- Implement CLI to setup config.
  - Save/update session_id so browser is only needed once.
- Generate new configuration file with the command line.
- Make reusable fixtures instead of setting up every test
- Get rid of `envchain`?
  - Store config/credentials in `~/.config/`?
  - Encrypt config, use Keyring or other OS-level secure storage?
    - Possible to write a gem with native extension based on <https://github.com/hrantzsch/keychain>? (or <https://github.com/hwchen/keyring-rs>?)
  - Open browser, ask user to log into MoneyForward and store cookie? (Does it expire though?)
    - Or prompt user from credentials in terminal and fill in form in headless browser
    - Need to handle case when cookie has expired:
      > セキュリティ設定	最終利用時間から[30日]後に自動ログアウト
- Log how many transactions were duplicates after import
