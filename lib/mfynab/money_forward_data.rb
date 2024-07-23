# frozen_string_literal: true

require "csv"

module MFYNAB
  class MoneyForwardData
    HEADERS = {
      include: "計算対象",
      date: "日付",
      content: "内容",
      amount: "金額（円）",
      account: "保有金融機関",
      category: "大項目",
      subcategory: "中項目",
      memo: "メモ",
      transfer: "振替",
      id: "ID",
    }

    def initialize
      @transactions = {}
    end

    def read_all_csv(path)
      Dir[File.join(path, "*.csv")].each do |file|
        read_csv(file)
      end
    end

    def read_csv(csv_file)
      puts "Reading #{csv_file}"
      CSV.foreach(
        csv_file,
        headers: true,
        converters: :all,
        header_converters: csv_header_converters,
      ) do |row|
        transactions[row["account"]] ||= []
        transactions[row["account"]] << row.to_h
      end
    end

    def to_h
      transactions
    end

    private

      attr_reader :transactions

      def csv_header_converters
        lambda do |header|
          HEADERS.key(header)&.to_s || header
        end
      end
  end
end
