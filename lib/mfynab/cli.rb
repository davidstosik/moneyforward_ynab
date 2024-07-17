# frozen_string_literal: true

require "debug"
require "yaml"
require "mfynab/money_forward_downloader"
require "mfynab/money_forward_data"
require "mfynab/ynab_transaction_importer"

class CLI
  def self.start(argv)
    new(argv).start
  end

  def initialize(argv)
    @argv = argv
  end

  def start
    puts "Running..."

    Dir.mktmpdir("mfynab") do |save_path|
      MFYNAB::MoneyForwardDownloader
        .new(
          username: config["moneyforward_username"],
          password: config["moneyforward_password"],
          to: save_path,
        )
        .run

      data = MFYNAB::MoneyForwardData.new
      data.read_all_csv(save_path)
      @mf_data = data.to_h
    end

    MFYNAB::YnabTransactionImporter.new(
      config["ynab_access_token"],
      config["ynab_budget"],
      config["accounts"],
    ).run(@mf_data)
  end

  private

    attr_reader :argv

    def config_file
      if argv.empty?
        raise "You need to pass a config file"
      end

      argv[0]
    end

    def config
      @_config ||= YAML
        .load_file(config_file)
        .values
        .first
        .merge(
          "ynab_access_token" => ENV["YNAB_ACCESS_TOKEN"],
          "moneyforward_username" =>ENV["MONEYFORWARD_USERNAME"],
          "moneyforward_password" => ENV["MONEYFORWARD_PASSWORD"],
        )
    end
end
