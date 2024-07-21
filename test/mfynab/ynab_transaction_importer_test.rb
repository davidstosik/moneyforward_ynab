# frozen_string_literal: true

require "test_helper"
require "mfynab/ynab_transaction_importer"
require "support/ynab_requests"

module MFYNAB
  class YnabTransactionImporterTest < Minitest::Test
    include YnabRequests

    def test_happy_path
      mf_account_name = "MF Account"
      ynab_budget = {
        id: "budget_id",
        name: "My Budget",
      }
      ynab_account = {
        id: "ynab_account",
        name: "YNAB Account",
      }

      stub_ynab_budgets([ynab_budget])
      stub_ynab_accounts(ynab_budget[:id], [ynab_account])
      expected_transactions_request = stub_ynab_transactions(
        ynab_budget[:id],
        transactions: [{
          account_id: ynab_account[:id],
          amount: 77_000,
          payee_name: "transaction content",
          date: "2024-07-17",
          cleared: "cleared",
          memo: "transaction content - 食費/食料品",
          import_id: "MFBY:v1:123abc"
        }]
      )

      importer = YnabTransactionImporter.new(
        "dummy_api_key",
        ynab_budget[:name],
        [{ "money_forward_name" => mf_account_name, "ynab_name" => ynab_account[:name] }]
      )
      importer.run({
        mf_account_name => [{
          "include" => "1",
          "date" => "2024/07/17",
          "content" => "transaction content",
          "amount" => 77,
          "account" => mf_account_name,
          "category" => "食費",
          "subcategory" => "食料品",
          "memo" => "",
          "id" => "123abc",
        }],
      })

      assert_requested(expected_transactions_request)
    end
  end
end
