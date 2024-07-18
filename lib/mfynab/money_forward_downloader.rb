# frozen_string_literal: true

require "capybara/cuprite"

module MFYNAB
  class MoneyForwardDownloader
    CAPYBARA_DRIVER_NAME = :cuprite_mfynab

    def initialize(username:, password:, to:)
      @username = username
      @password = password
      @save_path = to
    end

    def run
      with_capypara_session do |session|
        session.driver.add_headers({
          "Accept-Language" => "en-US,en;q=0.2,ja;q=0.8,fr;q=0.7,ja-JP;q=0.6",
          "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
        })

        puts "Visiting login page"
        session.visit("https://moneyforward.com/sign_in")

        puts "Filling in username"
        session.fill_in("メールアドレス", with: username)
        session.click_on("ログインする")

        puts "Filling in password"
        session.fill_in("パスワード", with: password)
        session.click_on("ログインする")

        if session.has_text?("スキップする")
          puts "Skipping passkey dialog"
          session.click_on("スキップする")
        end

        puts "Waiting for login to complete"
        session.click_on("履歴の詳細を見る")

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
          session.has_text?(date_range_proc.call)

          session.find("a", text: /ダウンロード/).click

          file_count_before = Dir[File.join(save_path, "*.csv")].count
          session.click_on("CSVファイル")
          session.document.synchronize do
            unless File.exist?(File.join(save_path, file_name_proc.call))
              puts "Waiting for #{file_name_proc.call} download to complete"
              sleep 0.2
              raise Capybara::ElementNotFound
            end
          end

          session.click_button("◄")
          start = start.prev_month
        end

        puts "Done downloading"
      end
    end

    private

    attr_reader :username, :password, :save_path

    def with_capypara_session(&block)
      # old_threadsafe = Capybara.threadsafe
      old_save_path = Capybara.save_path

      Capybara.threadsafe = true
      Capybara.save_path = save_path

      register_capybara_driver

      session = Capybara::Session.new(CAPYBARA_DRIVER_NAME) do |config|
        config.default_max_wait_time = 10
      end

      yield session
    ensure
      session&.quit if defined?(session)
      Capybara.save_path = old_save_path
      # FIXME:
      #  Capybara.threadsafe setting cannot be changed once a session is created
      #  I'm not comfortable setting Capybara.threadsafe in this method,
      #  especially if I cannot restore its original value.
      #  Is using Capybara even the right thing?
      # Capybara.threadsafe = old_threadsafe
    end

    def register_capybara_driver
      return if Capybara.drivers[CAPYBARA_DRIVER_NAME]

      Capybara.register_driver(CAPYBARA_DRIVER_NAME) do |app|
        Capybara::Cuprite::Driver.new(
          app,
          window_size: [1200, 800],
          headless: !ENV.key?("NO_HEADLESS"),
          save_path: save_path,
          timeout: 30,
        )
      end
    end
  end
end
