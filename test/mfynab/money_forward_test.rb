# frozen_string_literal: true

require "test_helper"
require "csv"
require "mfynab/money_forward"
require "support/fake_moneyforward_app"

module MFYNAB
  class MoneyForwardTest < Minitest::Test
    def test_get_session_id_raises_if_wrong_credentials
      while_running_fake_moneyforward_app do |host, port|
        money_forward = MoneyForward.new(base_url: "http://#{host}:#{port}")

        assert_raises(RuntimeError, "Login failed") do
          money_forward.get_session_id(
            username: "david@example.com",
            password: "wrong_password",
          )
        end
      end
    end

    def test_get_session_id_happy_path
      while_running_fake_moneyforward_app do |host, port|
        session_id = MoneyForward.new(
          base_url: "http://#{host}:#{port}",
        ).get_session_id(
          username: "david@example.com",
          password: "Passw0rd!",
        )

        assert_equal "dummy_session_id", session_id
      end
    end

    def test_download_csv_happy_path
      session_id = "dummy_session_id"
      dates = 0.upto(2).map do |i|
        first_of_the_month << i
      end
      expected_requests = dates.map do |date|
        stub_money_forward_csv_download(date: date)
          .with(headers: { cookie: "_moneybook_session=#{session_id}" })
      end

      Dir.mktmpdir do |tmpdir|
        MoneyForward.new.download_csv(
          session_id: session_id,
          path: tmpdir,
        )

        expected_files = dates.map { "#{_1.strftime("%Y-%m")}.csv" }
        produced_files = Dir[File.join(tmpdir, "*.csv")].map { File.basename(_1) }
        assert_equal expected_files.sort, produced_files.sort
      end

      expected_requests.each { assert_requested(_1) }
    end

    private

    def stub_money_forward_csv_download(date:, transactions: [])
      headers = [
        "計算対象",
        "日付",
        "内容",
        "金額（円）",
        "保有金融機関",
        "大項目",
        "中項目",
        "メモ",
        "振替",
        "ID"
      ]

      if transactions.empty?
        transactions = [[
          "1",
          date.strftime("%Y/%m/%d"),
          "物販 髙島屋",
          "-1000",
          "モバイルSuica",
          "未分類",
          "未分類",
          "",
          "0",
          "transaction_id",
        ]]
      end

      csv = CSV.generate(force_quotes: true, encoding: Encoding::SJIS) do |csv|
        csv << headers
        transactions.each { csv << _1 }
      end

      stub_request(:get, "https://moneyforward.com/cf/csv?from=#{date.strftime("%Y/%m/%d")}")
        .to_return(body: csv)
    end

    def first_of_the_month
      today = Date.today
      today - today.day + 1
    end

    def while_running_fake_moneyforward_app
      WebMock.disable_net_connect!(allow_localhost: true)
      host = "127.0.0.1"
      port = 4567

      webapp_thread = Thread.new do
        require "rackup/handler/webrick"

        Rackup::Handler::WEBrick.run(
          FakeMoneyforwardApp,
          Host: host,
          Port: port,
          AccessLog: [],
          Logger: WEBrick::Log.new(nil, 0)
        )
      end

      Timeout.timeout(5) do
        sleep 0.1 until responsive?(webapp_thread, host, port)
      end

      yield host, port
    ensure
      webapp_thread&.terminate
      WebMock.disable_net_connect!
    end

    # Method inspired by Capybara:
    # https://github.com/teamcapybara/capybara/blob/0480f90168a40780d1398c75031a255c1819dce8/lib/capybara/server.rb#L53-L61
    def responsive?(webapp_thread, host, port)
      return false if webapp_thread&.join(0)

      res = Net::HTTP.start(host, port, max_retries: 0) do |http|
        req = Net::HTTP::Get.new("/")
        http.request(req)
      end

      res.is_a?(Net::HTTPSuccess)
    rescue SystemCallError, Net::ReadTimeout, OpenSSL::SSL::SSLError
      false
    end
  end
end
