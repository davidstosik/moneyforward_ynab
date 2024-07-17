require "thor"
require "mfynab/cli"

module MFYNAB
  class ThorCLI < Thor
    def self.exit_on_failure?
      true
    end

    option :config, required: true, desc: <<~DESC
      Path to your configuration file.
      See mfynab/config/example.yml for an example.
    DESC
    desc "sync", "synchronise transactions from MoneyForward to YNAB"
    long_desc <<~LONGDESC, wrap: false
      `mfynab sync` will:
        - read your config file
        - log into your MoneyForward account
        - download the transactions for the last 3 months
        - convert the transactions to a format that YNAB can understand
        - import the transactions to YNAB using the YNAB API
    LONGDESC
    def sync
      CLI.new([options[:config]]).start
    end
  end
end
