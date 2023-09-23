# MoneyForward to YNAB migrator

This Ruby script downloads transaction history from Money Forward then uploads it to YNAB.

## Principle

- Use [Capybara](https://github.com/teamcapybara/capybara) with the [Cuprite](https://github.com/rubycdp/cuprite) driver to log into the Money Forward website and download transaction history CSV files.
- Parse the CSV files and converts the data to a format that works with YNAB.
- Use [YNAB API Ruby library](https://github.com/ynab/ynab-sdk-ruby) to post transactions to your YNAB budget.
- Budget and account mappings are set in a configuration file (`config.yml`).

## Setup

You'll need Ruby and Bundler.

```
# Install dependencies
bundle install

# Start a config.yml file
cp config.yml.example config.yml
```

The script currently looks for environment variables for credentials:
- `MONEYFORWARD_USERNAME`
- `MONEYFORWARD_PASSWORD`
- `YNAB_ACCESS_TOKEN`

You can for example use [envchain](https://github.com/sorah/envchain) to manage those credentials:

```
envchain --set --noecho mf_ynab MONEYFORWARD_USERNAME MONEYFORWARD_PASSWORD YNAB_ACCESS_TOKEN
```

## Running

To run, you'll simply need to set the environment variables. Using `envchain`, that'll look like this:

```
envchain mf_ynab bundle exec download.rb
```
