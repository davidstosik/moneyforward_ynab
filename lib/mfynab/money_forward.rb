# frozen_string_literal: true

require "capybara/cuprite"

module MFYNAB
  class MoneyForward
    CAPYBARA_DRIVER_NAME = :cuprite_mfynab
    DEFAULT_BASE_URL = "https://moneyforward.com"
    SIGNIN_PATH = "/sign_in"
    CSV_PATH = "/cf/csv"
    SESSION_COOKIE_NAME = "_moneybook_session"
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

    def initialize(base_url: DEFAULT_BASE_URL)
      @base_url = URI(base_url)
    end

    def get_session_id(username:, password:)
      with_capypara_session do |session|
        session.driver.add_headers({
          "Accept-Language" => "en-US,en;q=0.2,ja;q=0.8,fr;q=0.7,ja-JP;q=0.6",
          "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/116.0.0.0 Safari/537.36",
        })

        puts "Visiting login page"
        session.visit("#{base_url}#{SIGNIN_PATH}")

        puts "Filling in username"
        session.fill_in("メールアドレス", with: username)
        session.click_on("ログインする")

        puts "Filling in password"
        session.fill_in("パスワード", with: password)
        session.click_on("ログインする")

        return session.driver.cookies[SESSION_COOKIE_NAME].value
      end
    end

    def download_csv(session_id:, path:)
      month = Date.today
      month -= month.day - 1 # First day of month

      Net::HTTP.start(base_url.host, use_ssl: true) do |http|
        3.times do
          http.response_body_encoding = Encoding::SJIS

          request = Net::HTTP::Get.new(
            "#{CSV_PATH}?from=#{month.strftime("%Y/%m/%d")}",
            {
              "Cookie" => "#{SESSION_COOKIE_NAME}=#{session_id}",
              "User-Agent" => USER_AGENT,
            }
          )

          date_string = month.strftime("%Y-%m")

          puts "Downloading CSV for #{date_string}"

          result = http.request(request)
          raise unless result.is_a?(Net::HTTPSuccess)
          raise unless result.body.valid_encoding?

          # FIXME:
          # I don't really need to save the CSV files to disk anymore.
          # Maybe just return parsed CSV data?
          File.open(File.join(path, "#{date_string}.csv"), "wb") do |file|
            file << result.body.encode(Encoding::UTF_8)
          end

          month = month.prev_month
        end
      end
    end

    private

    attr_reader :base_url

    def with_capypara_session(&block)
      # old_threadsafe = Capybara.threadsafe
      Capybara.threadsafe = true

      register_capybara_driver

      session = Capybara::Session.new(CAPYBARA_DRIVER_NAME) do |config|
        config.default_max_wait_time = 10
      end

      yield session
    ensure
      session&.quit if defined?(session)
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
          timeout: 30,
        )
      end
    end
  end
end
