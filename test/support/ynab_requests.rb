# frozen_string_literal: true

module MFYNAB
  module YnabRequests
    private

      def stub_ynab_accounts(budget_id, accounts = [], server_knowledge: 1)
        accounts << {} if accounts.empty?

        accounts_data = accounts.map.with_index do |account, index|
          ynab_account_defaults.merge(account).tap do |account|
            id_name = "account_#{index}"
            account[:id] ||= id_name
            account[:name] ||= id_name
            account[:transfer_payee_id] ||= "transfer_payee_#{index}"
          end
        end

        response = {
          data: {
            accounts: accounts_data,
            server_knowledge: server_knowledge,
          },
        }

        stub_ynab_request(:get, "/budgets/#{budget_id}/accounts").to_return(
          status: 200,
          headers: {},
          body: response.to_json,
        )
      end

      def stub_ynab_budgets(budgets = [], default: nil)
        budgets << {} if budgets.empty?

        budget_data = budgets.map.with_index do |budget, index|
          ynab_budget_defaults.merge(budget).tap do |budget|
            id_name = "budget_#{index}"
            budget[:id] ||= id_name
            budget[:name] ||= id_name
          end
        end

        response = {
          data: {
            budgets: budget_data,
            default_budget: default,
          },
        }

        stub_ynab_request(:get, "/budgets").to_return(
          status: 200,
          headers: {},
          body: response.to_json,
        )
      end

      def stub_ynab_transactions(budget_id, transactions:)
        output_transactions = transactions.map.with_index do |transaction, index|
          { id: "transaction_#{index}" }.merge(transaction)
        end
        stub_ynab_request(:post, "/budgets/#{budget_id}/transactions")
          .with(body: { transactions: transactions })
          .to_return(
            status: 201,
            headers: {},
            body: {
              data: {
                transaction_ids: output_transactions.map { _1[:id] },
                duplicate_import_ids: [],
                transactions: output_transactions,
                server_knowledge: 1,
              },
            }.to_json,
          )
      end

      def stub_ynab_request(method, path)
        stub_request(method, "https://api.ynab.com/v1#{path}")
          .with(
            headers: { "Content-Type" => "application/json" }
          )
      end

      def ynab_account_defaults
        @_ynab_account_defaults ||= {
          id: nil,
          transfer_payee_id: nil,
          name: nil,
          type: "cash",
          on_budget: true,
          closed: false,
          note: nil,
          balance: 0,
          cleared_balance: 0,
          uncleared_balance: 0,
          direct_import_linked: false,
          direct_import_in_error: false,
          last_reconciled_at: Time.now - 3600,
          debt_original_balance: nil,
          debt_interest_rates: {},
          debt_minimum_payments: {},
          debt_escrow_amounts: {},
          deleted: false,
        }
      end

      def ynab_budget_defaults
        @_ynab_budget_defaults ||= begin
          today = Date.today
          last_month = Date.new(today.year, today.month, 1)
          first_month = last_month << 12
          {
            id: nil,
            name: nil,
            last_modified_on: Time.now - 3600,
            first_month: first_month,
            last_month: last_month,
            date_format: {
              format: "YYYY-MM-DD",
            },
            currency_format: {
              iso_code: "JPY",
              example_format: "123,456",
              decimal_digits: 0,
              decimal_separator: ".",
              symbol_first: true,
              group_separator: ",",
              currency_symbol: "¥",
              display_symbol: true,
            },
          }
        end
      end
  end
end
