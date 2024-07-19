# frozen_string_literal: true

require "debug"
require "capybara/cuprite"
require "csv"
require "ynab"
require "yaml"

class CLI
  # See https://github.com/ynab/ynab-sdk-ruby/issues/77
  YNAB_MEMO_MAX_SIZE = 500
  YNAB_PAYEE_MAX_SIZE = 200
  YNAB_IMPORT_ID_MAX_LENGTH = 36

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

    if steps.include?("download")
      Capybara.threadsafe = true
      Capybara.save_path = save_path

      # Create folder if it doesn't exist
      FileUtils.mkdir_p(save_path)
      FileUtils.rm_f(latest_symlink)
      FileUtils.ln_s(save_path, latest_symlink)

      Capybara.register_driver(:cuprite) do |app|
        Capybara::Cuprite::Driver.new(
          app,
          window_size: [1200, 800],
          headless: !ENV.key?("NO_HEADLESS"),
          save_path: save_path,
          timeout: 30,
        )
      end

      @session = Capybara::Session.new(:cuprite) do |config|
        config.default_max_wait_time = 10
      end

      @session.driver.add_headers({
        "Accept-Language" => "en-US,en;q=0.2,ja;q=0.8,fr;q=0.7,ja-JP;q=0.6",
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
      })

      puts "Visiting login page"
      @session.visit("https://moneyforward.com/sign_in")

      #puts "Clicking login button"
      #@session.first(:link_or_button, "ログイン").click

      puts "Filling in username"
      @session.fill_in("メールアドレス", with: config["moneyforward_username"])
      @session.click_on("ログインする")

      puts "Filling in password"
      @session.fill_in("パスワード", with: config["moneyforward_password"])
      @session.click_on("ログインする")

      if @session.has_text?("スキップする")
        puts "Skipping passkey dialog"
        @session.click_on("スキップする")
      end

      puts "Waiting for login to complete"
      @session.click_on("履歴の詳細を見る")

      # FIXME do I need to refresh Money Forward accounts first? (optional)

      today = Date.today
      start = Date.new(today.year, today.month, 1)

      date_range_proc = proc do
        [start, start.next_month.prev_day].map do |date|
          date.strftime("%Y/%m/%d")
        end.join(" - ")
      end

      file_name_proc = proc do
        dates = [start, start.next_month.prev_day].map do |date|
          date.strftime("%Y-%m-%d")
        end.join("_")
        "収入・支出詳細_#{dates}.csv"
      end

      3.times do
        puts "Downloading CSV for #{date_range_proc.call}"

        # Wait for the date range to show
        @session.has_text?(date_range_proc.call)

        @session.find("a", text: /ダウンロード/).click

        file_count_before = Dir[File.join(save_path, "*.csv")].count
        @session.click_on("CSVファイル")
        @session.document.synchronize do
          unless File.exist?(File.join(save_path, file_name_proc.call))
            puts "Waiting for #{file_name_proc.call} download to complete"
            sleep 0.2
            raise Capybara::ElementNotFound
          end
        end

        @session.click_button("◄")
        start = start.prev_month
      end

      puts "Done downloading"
      @session.quit
    end

    if steps.include?("convert")
      csv_header_converters = lambda do |header|
        # Translate following headers from Japanese to English
        # 計算対象、日付、内容、金額（円）、保有金融機関、大項目、中項目、メモ、振替、ID
        case header
        when "計算対象" then "include"
        when "日付" then "date"
        when "内容" then "content"
        when "金額（円）" then "amount"
        when "保有金融機関" then "account"
        when "大項目" then "category"
        when "中項目" then "subcategory"
        when "メモ" then "memo"
        when "ID" then "id"
        else header
        end
      end

      @mf_data = {}

      Dir[File.join(latest_symlink, "*.csv")].each do |file|
        puts "Reading #{file}"
        CSV.foreach(
          file,
          headers: true,
          encoding: "SJIS:UTF-8",
          converters: :all,
          header_converters: csv_header_converters,
        ) do |row|
          @mf_data[row["account"]] ||= []
          @mf_data[row["account"]] << row
        end
      end

      #if steps.include?("csv-export")
      #  output_path = File.join(project_root, "out", script_time.strftime("%Y%m%d-%H%M%S"))
      #  FileUtils.mkdir_p(output_path)

      #  @mf_data.each do |account, data|
      #    CSV.open(
      #      File.join(output_path, "#{account}.csv"),
      #      "wb",
      #      headers: %w[Date Payee Memo Amount],
      #      write_headers: true,
      #    ) do |csv|
      #      data.each do |row|
      #        csv << [
      #          Date.parse(row["date"]).strftime("%Y/%m/%d"),
      #          row["content"],
      #          "#{row["category"]}/#{row["subcategory"]} - #{row["content"]} - #{row["memo"]}",
      #          row["amount"],
      #        ]
      #      end
      #    end
      #  end
      #end

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
              payee_name: row["content"][0, YNAB_PAYEE_MAX_SIZE],
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
        .slice(0, YNAB_MEMO_MAX_SIZE)
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

      digest_max_length = 28  # this leaves 8 characters for the prefix

      id = row["id"]

      # Only hash if the ID would exceed YNAB's limit.
      # This improves backwards compatibility with old import_ids.
      if prefix.length + id.length > YNAB_IMPORT_ID_MAX_LENGTH
        id = Digest::SHA256.hexdigest(id)[0, digest_max_length]
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
