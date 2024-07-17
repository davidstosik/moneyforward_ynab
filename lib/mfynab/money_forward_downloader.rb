# frozen_string_literal: true

require "capybara/cuprite"

module MFYNAB
  class MoneyForwardDownloader
    def initialize(username:, password:, to:)
      @username = username
      @password = password
      @save_path = to
    end

    def run
      Capybara.threadsafe = true
      Capybara.save_path = save_path

      # Create folder if it doesn't exist
      FileUtils.mkdir_p(save_path)

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

      puts "Filling in username"
      @session.fill_in("メールアドレス", with: username)
      @session.click_on("ログインする")

      puts "Filling in password"
      @session.fill_in("パスワード", with: password)
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

    private

    attr_reader :username, :password, :save_path
  end
end
