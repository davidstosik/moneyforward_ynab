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

## Todo

- Force MoneyForward to sync all accounts before downloading data. (Can take a while.)
- Use Thor to manage the CLI
