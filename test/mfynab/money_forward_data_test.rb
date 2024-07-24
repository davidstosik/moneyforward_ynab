# frozen_string_literal: true

require "test_helper"
require "mfynab/money_forward_data"

module MFYNAB
  class MoneyForwardDataTest < Minitest::Test
    def test_read_all_csv_reads_all_csv_in_directory_and_groups_by_account
      csv1 = MoneyForwardCsv.new(
        Date.new(2024, 7, 1),
        [{
          "保有金融機関" => "account 1",
          "ID" => "transaction_id_1",
        }],
      )
      csv2 = MoneyForwardCsv.new(
        Date.new(2024, 6, 1),
        [{
          "保有金融機関" => "account 2",
          "ID" => "transaction_id_2",
        }],
      )
      Dir.mktmpdir do |dir|
        csv1.save_to(dir)
        csv2.save_to(dir)

        data = MoneyForwardData.new(logger: null_logger)
        data.read_all_csv(dir)

        transactions = data.to_h

        assert_equal ["account 1", "account 2"], transactions.keys.sort
        transactions.each_value do |account_transactions|
          assert_equal 1, account_transactions.size
        end

        assert_equal(
          ["account 1", "transaction_id_1"],
          transactions["account 1"].first.values_at("account", "id"),
        )

        assert_equal(
          ["account 2", "transaction_id_2"],
          transactions["account 2"].first.values_at("account", "id"),
        )
      end
    end

    def test_read_csv_reads_csv_file_and_converts_headers
      csv = MoneyForwardCsv.new(
        Date.new(2024, 7, 1),
        [{
          "計算対象" => "1",
          "日付" => "2024/07/15",
          "内容" => "物販 髙島屋",
          "金額（円）" => "-1000",
          "保有金融機関" => "モバイルSuica",
          "大項目" => "未分類",
          "中項目" => "未分類",
          "メモ" => "",
          "振替" => "0",
          "ID" => "transaction_id",
        }],
      )
      Tempfile.open("mfynabcsv") do |file|
        csv.save_to(file)

        data = MoneyForwardData.new(logger: null_logger)
        data.read_csv(file)

        expected_transactions = {
          "モバイルSuica" => [{
            "include" => 1,
            "date" => "2024/07/15",
            "content" => "物販 髙島屋",
            "amount" => -1000,
            "account" => "モバイルSuica",
            "category" => "未分類",
            "subcategory" => "未分類",
            "memo" => "",
            "transfer" => 0,
            "id" => "transaction_id",
          }],
        }

        assert_equal expected_transactions, data.to_h
      end
    end

    private

      def null_logger
        Logger.new(File::NULL)
      end
  end
end
