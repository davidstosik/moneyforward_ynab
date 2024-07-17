# frozen_string_literal: true

require "debug"
require "ynab"
require "yaml"
require "mfynab/money_forward_downloader"
require "mfynab/money_forward_data"

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
        ynab_budget = config["ynab_budget"]
        ynab_api = YNAB::API.new(config["ynab_access_token"])

        budget = ynab_api.budgets.get_budgets.data.budgets.find { _1.name == ynab_budget }
        accounts = ynab_api.accounts.get_accounts(budget.id).data.accounts

        config["accounts"].each do |mapping|
          account = accounts.find { _1.name.include?(mapping["ynab_name"]) }
          unless account
            puts "Could not find YNAB account for #{mapping["ynab_name"]}"
            next
          end

          # Skip if no transactions were found for this account
          next unless @mf_data.key?(mapping["money_forward_name"])

          transactions = @mf_data[mapping["money_forward_name"]].map do |row|
            {
              account_id: account.id,
              amount: row["amount"] * 1_000,
              payee_name: row["content"][0, 100],
              date: Date.strptime(row["date"], "%Y/%m/%d").strftime("%Y-%m-%d"),
              cleared: "cleared",
              memo: generate_memo_for(row),
              import_id: generate_import_id_for(row),
            }
          end

          wrapper = YNAB::PostTransactionsWrapper.new(transactions:)

          begin
            ynab_api.transactions.create_transactions(budget.id, wrapper)
          rescue StandardError => e
            puts "Error importing transactions for #{budget.name}. #{e} : #{e.detail}"
          end
        end
      end
    end
  end

  private

    attr_reader :argv

    def generate_memo_for(row)
      category = row
        .values_at("category", "subcategory")
        .delete_if { _1.nil? || _1.empty? || _1 == "未分類" }
        .join("/")

      memo_parts = [
        row["memo"], # prioritize memo if present, since it's user input
        row["content"],
        category,
      ]

      memo_parts
        .delete_if { _1.nil? || _1.empty? }
        .join(" - ")
        .slice(0, 200) # YNAB's API currently limits memo to 200 characters,
      # even though YNAB itself allows longer memos. See:
      # https://github.com/ynab/ynab-sdk-ruby/issues/77
    end

    # ⚠️ Be very careful when changing this method!
    #
    # A different import_id can cause MFYNAB to create duplicate transactions.
    #
    # import_id is scoped to an account in a budget, this means that:
    # - if 2 transactions have the same import_id, but are in different
    #   accounts then they will be imported as 2 unrelated transactions.
    # - if 2 transactions in the same account have the same import_id,
    #   then the second transaction will be ignored,
    #   even if it has a different date and/or amount.
    # Note that it might be useful for the import_id to stay consistent even if
    # the transaction amount changes, since a transaction that originally
    # appeared as a low-amount authorization might be updated to its final
    # amount later.
    # (I don't know what that means for cleared and reconciled transactions...)
    def generate_import_id_for(row)
      # Uniquely identify transactions to avoid conflicts with other potential import scripts
      # Note: I don't remember why I named it MFBY (why not MFYNAB or MFY?),
      # but changing it now would require a lot of work in preventing import
      # duplicates due to inconsistent import_id.
      prefix = "MFBY:v1:"

      max_length = 36     # YNAB API limit
      id_max_length = 28  # this leaves 8 characters for the prefix

      id = row["id"]

      # Only hash if the ID would exceed YNAB's limit.
      # This improves backwards compatibility with old import_ids.
      if prefix.length + id.length > max_length
        id = Digest::SHA256.hexdigest(id)[0, id_max_length]
      end

      prefix + id
    end

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
