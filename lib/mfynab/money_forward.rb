# frozen_string_literal: true

require "ferrum"

module MFYNAB
  class MoneyForward
    DEFAULT_BASE_URL = "https://moneyforward.com"
    SIGNIN_PATH = "/sign_in"
    CSV_PATH = "/cf/csv"
    SESSION_COOKIE_NAME = "_moneybook_session"
    USER_AGENT = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
                 "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36"

    def initialize(base_url: DEFAULT_BASE_URL)
      @base_url = URI(base_url)
    end

    def get_session_id(username:, password:)
      with_ferrum do |browser|
        browser.goto("#{base_url}#{SIGNIN_PATH}")
        browser.at_css("input[name='mfid_user[email]']").focus.type(username)
        browser.at_css("input[name='mfid_user[password]']").focus.type(password)
        browser.at_css("button#submitto").click

        # FIXME: use custom error class
        raise "Login failed" unless browser.cookies[SESSION_COOKIE_NAME]

        browser.cookies[SESSION_COOKIE_NAME].value
      end
    end

    def download_csv(session_id:, path:)
      month = Date.today
      month -= month.day - 1 # First day of month

      Net::HTTP.start(base_url.host, use_ssl: true) do |http|
        http.response_body_encoding = Encoding::SJIS

        3.times do
          date_string = month.strftime("%Y-%m")

          puts "Downloading CSV for #{date_string}"

          # FIXME: I don't really need to save the CSV files to disk anymore.
          # Maybe just return parsed CSV data?
          File.open(File.join(path, "#{date_string}.csv"), "wb") do |file|
            file << download_csv_string(date: month, session_id: session_id)
          end

          month = month.prev_month
        end
      end
    end

    def download_csv_string(date:, session_id:)
      Net::HTTP.start(base_url.host, use_ssl: true) do |http|
        http.response_body_encoding = Encoding::SJIS

        request = Net::HTTP::Get.new(
          "#{CSV_PATH}?from=#{date.strftime('%Y/%m/%d')}",
          {
            "Cookie" => "#{SESSION_COOKIE_NAME}=#{session_id}",
            "User-Agent" => USER_AGENT,
          },
        )

        result = http.request(request)
        raise unless result.is_a?(Net::HTTPSuccess)
        raise unless result.body.valid_encoding?

        result.body.encode(Encoding::UTF_8)
      end
    end

    private

      attr_reader :base_url

      def with_ferrum
        browser = Ferrum::Browser.new(timeout: 30, headless: !ENV.key?("NO_HEADLESS"))
        browser.headers.add({
          "Accept-Language" => "en-US,en",
          "User-Agent" => USER_AGENT,
        })
        yield browser
      rescue
        browser.screenshot(path: "screenshot.png")
        puts "An error occurred and a screenshot was saved to ./screenshot.png"
        raise
      ensure
        browser&.quit
      end
  end
end
