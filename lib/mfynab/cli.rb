# frozen_string_literal: true

require "debug"
require "yaml"
require "mfynab/money_forward"
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
      money_forward.download_csv(
        session_id: session_id,
        path: save_path,
      )

      data = MFYNAB::MoneyForwardData.new
      data.read_all_csv(save_path)
      ynab_transaction_importer.run(data.to_h)
    end
  end

  private

    attr_reader :argv

    def session_id
      @_session_id ||= money_forward.get_session_id(
        username: config["moneyforward_username"],
        password: config["moneyforward_password"],
      )
    end

    def ynab_transaction_importer
      @_ynab_transaction_importer ||= MFYNAB::YnabTransactionImporter.new(
        config["ynab_access_token"],
        config["ynab_budget"],
        config["accounts"],
      )
    end

    def money_forward
      @_money_forward ||= MFYNAB::MoneyForward.new
    end

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
          "ynab_access_token" => ENV.fetch("YNAB_ACCESS_TOKEN"),
          "moneyforward_username" => ENV.fetch("MONEYFORWARD_USERNAME"),
          "moneyforward_password" => ENV.fetch("MONEYFORWARD_PASSWORD"),
        )
    end
end
