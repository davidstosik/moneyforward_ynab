# MoneyForward to YNAB migrator

This Ruby script downloads transaction history from Money Forward then uploads
it to YNAB.

## Principle

- Use [Capybara](https://github.com/teamcapybara/capybara) with the [Cuprite](https://github.com/rubycdp/cuprite)
  driver to log into the Money Forward website and download transaction history
  CSV files.
- Parse the CSV files and converts the data to a format that works with YNAB.
- Use [YNAB API Ruby library](https://github.com/ynab/ynab-sdk-ruby) to post
  transactions to your YNAB budget.
- Budget and account mappings are set in a configuration file (`config.yml`).

## Setup

You'll need Ruby and Bundler.

```sh
# Install dependencies
bundle install

# Start a config YAML file
cp config/example.yml config/david.yml
```

The script currently looks for credentials in environment variables:

- `MONEYFORWARD_USERNAME`
- `MONEYFORWARD_PASSWORD`
- `YNAB_ACCESS_TOKEN`

You can for example use [envchain](https://github.com/sorah/envchain) to manage
those credentials:

```sh
envchain --set --noecho mfynab MONEYFORWARD_USERNAME MONEYFORWARD_PASSWORD YNAB_ACCESS_TOKEN
```

## Running

To run, you'll simply need to set the environment variables.
Using `envchain`, that'll look like this:

```sh
envchain mfynab bin/mfynab config/david.yml
```

## Development

After checking out the repo, run `bundle install` to install dependencies. Then, run `bin/rake test` to run the tests.

## Todo

- Force MoneyForward to sync all accounts before downloading data. (Can take a while.)
- Use Thor to manage the CLI. (And/or TTY?)
- Write more tests.
- Setup CI.
- Implement `Transaction` model to extract some logic from existing classes.
- Turn into a gem and publish.
- Replace Capybara?
- Implement CLI to setup config.
- Get rid of `envchain`?
  - Store config/credentials in `~/.config/`?
  - Encrypt config, use Keyring or other OS-level secure storage?
    - Possible to write a gem with native extension based on <https://github.com/hrantzsch/keychain>?
  - Open browser, ask user to log into MoneyForward and store cookie? (Does it expire though?)
