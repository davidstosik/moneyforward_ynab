# frozen_string_literal: true

require "csv"

module MFYNAB
  class MoneyForwardData
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
    end
  end
end
