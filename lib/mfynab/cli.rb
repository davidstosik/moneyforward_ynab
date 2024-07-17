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
    script_time = Time.now

    puts "Running steps: #{steps.join(", ")}"

    # FIXME use temporary folder unless in "debug" mode?
    save_path = File.join(project_root, "in", script_time.strftime("%Y%m%d-%H%M%S"))
    latest_symlink = File.join(project_root, "in", "latest")
    FileUtils.ln_sf(save_path, latest_symlink)

    if steps.include?("download")
      MFYNAB::MoneyForwardDownloader
        .new(
          username: config["moneyforward_username"],
          password: config["moneyforward_password"],
          to: save_path,
        )
      .run
    end

    if steps.include?("convert")
      data = MFYNAB::MoneyForwardData.new
      data.read_all_csv(save_path)
      @mf_data = data.to_h

      if steps.include?("ynab-import")
        MFYNAB::YnabTransactionImporter.new(
          config["ynab_access_token"],
          config["ynab_budget"],
          config["accounts"],
        ).run(@mf_data)
      end
    end
  end

  private

    attr_reader :argv

    def config_file
      if argv.empty?
        raise "You need to pass a config file"
      end

      argv[0]
    end

    def steps
      %w(download convert csv-export ynab-import)
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

    def project_root
      @_project_root ||= File.expand_path("../..", __dir__)
    end
end
