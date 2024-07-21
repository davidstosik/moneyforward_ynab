# frozen_string_literal: true

require "test_helper"
require "csv"
require "mfynab/money_forward"

module MFYNAB
  class MoneyForwardTest < Minitest::Test
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

        expected_files = dates.map { "#{_1.strftime("%Y-%m-%d")}.csv" }
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
  end
end
