# frozen_string_literal: true

require "mfynab/money_forward_data"

module MFYNAB
  class MoneyForwardCsv
    def initialize(date, transactions = [default_transaction])
      @date = date
      @transactions = transactions.map do |transaction|
        default_transaction.merge(transaction)
      end
    end

    def save_to(path)
      if File.directory?(path)
        path = File.join(path,  file_name)
      end
      File.write(path, to_s)
    end

    def to_downloaded_string
      to_s(encoding: Encoding::SJIS)
    end

    def to_s(encoding: Encoding::UTF_8)
      CSV.generate(**csv_options.merge(encoding: encoding)) do |csv|
        transactions.each { csv << _1 }
      end
    end

    private

    attr_reader :date, :transactions

    def file_name
      "#{date.strftime('%Y-%m')}.csv"
    end

    def csv_options
      {
        force_quotes: true,
        headers: MoneyForwardData::HEADERS.values,
        write_headers: true,
      }
    end

    def default_transaction
      {
        "計算対象" => "1",
        "日付" => date.strftime("%Y/%m/%d"),
        "内容" => "物販 髙島屋",
        "金額（円）" => "-1000",
        "保有金融機関" => "モバイルSuica",
        "大項目" => "未分類",
        "中項目" => "未分類",
        "メモ" => "",
        "振替" => "0",
        "ID" => "transaction_id",
      }
    end
  end
end
