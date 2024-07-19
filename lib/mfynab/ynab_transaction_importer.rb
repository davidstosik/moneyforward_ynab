# frozen_string_literal: true

require "ynab"

module MFYNAB
  class YnabTransactionImporter
    def initialize(api_key, budget_name, account_mappings)
      @api_key = api_key
      @budget_name = budget_name
      @account_mappings = account_mappings
    end

    def run(mf_transactions)
      # FIXME instead of iterating over all configured accounts,
      # we should iterate over all accounts that have transactions:
      #     mf_transactions.map do |mf_account, mf_account_transactions|
      #       ynab_account_name = account_mappings.find { _1["money_forward_name"] == mf_account }["ynab_name"]
      #       ynab_account = accounts.find { _1.name.include?(ynab_account_name) }
      #       # ...
      #     end
      account_mappings.each do |mapping|
        account = accounts.find { _1.name.include?(mapping["ynab_name"]) }
        unless account
          puts "Could not find YNAB account for #{mapping["ynab_name"]}"
          next
        end

        # Skip if no transactions were found for this account
        next unless mf_transactions.key?(mapping["money_forward_name"])

        transactions = mf_transactions[mapping["money_forward_name"]].map do |row|
          {
            account_id: account.id,
            amount: row["amount"] * 1_000,
            payee_name: row["content"][0, 100],
            date: Date.strptime(row["date"], "%Y/%m/%d").strftime("%Y-%m-%d"),
            cleared: "cleared",
            memo: generate_memo_for(row),
            import_id: generate_import_id_for(row),
          }
        end

        begin
          ynab_transactions_api.create_transaction(budget.id, transactions: transactions)
        rescue StandardError => e
          puts "Error importing transactions for #{budget.name}. #{e} : #{e.detail}"
        end
      end
    end

    private

    attr_reader :api_key, :budget_name, :account_mappings

    def generate_memo_for(row)
      category = row
        .values_at("category", "subcategory")
        .delete_if { _1.nil? || _1.empty? || _1 == "未分類" }
        .join("/")

      memo_parts = [
        row["memo"], # prioritize memo if present, since it's user input
        row["content"],
        category,
      ]

      memo_parts
        .delete_if { _1.nil? || _1.empty? }
        .join(" - ")
        .slice(0, 200) # YNAB's API currently limits memo to 200 characters,
      # even though YNAB itself allows longer memos. See:
      # https://github.com/ynab/ynab-sdk-ruby/issues/77
    end

    # ⚠️ Be very careful when changing this method!
    #
    # A different import_id can cause MFYNAB to create duplicate transactions.
    #
    # import_id is scoped to an account in a budget, this means that:
    # - if 2 transactions have the same import_id, but are in different
    #   accounts then they will be imported as 2 unrelated transactions.
    # - if 2 transactions in the same account have the same import_id,
    #   then the second transaction will be ignored,
    #   even if it has a different date and/or amount.
    # Note that it might be useful for the import_id to stay consistent even if
    # the transaction amount changes, since a transaction that originally
    # appeared as a low-amount authorization might be updated to its final
    # amount later.
    # (I don't know what that means for cleared and reconciled transactions...)
    def generate_import_id_for(row)
      # Uniquely identify transactions to avoid conflicts with other potential import scripts
      # Note: I don't remember why I named it MFBY (why not MFYNAB or MFY?),
      # but changing it now would require a lot of work in preventing import
      # duplicates due to inconsistent import_id.
      prefix = "MFBY:v1:"

      max_length = 36     # YNAB API limit
      id_max_length = 28  # this leaves 8 characters for the prefix

      id = row["id"]

      # Only hash if the ID would exceed YNAB's limit.
      # This improves backwards compatibility with old import_ids.
      if prefix.length + id.length > max_length
        id = Digest::SHA256.hexdigest(id)[0, id_max_length]
      end

      prefix + id
    end

    def ynab_transactions_api
      @_ynab_transactions_api ||= YNAB::TransactionsApi.new(ynab_api_client)
    end

    def accounts
      @_accounts ||= YNAB::AccountsApi
      .new(ynab_api_client)
      .get_accounts(budget.id)
      .data
      .accounts
    end

    def budget
      @_budget ||= YNAB::BudgetsApi
        .new(ynab_api_client)
        .get_budgets
        .data
        .budgets
        .find { _1.name == budget_name }
    end

    def ynab_api_client
      @_ynab_api_client ||= YNAB::ApiClient.new(ynab_api_config)
    end

    def ynab_api_config
      @_ynab_api_config = YNAB::Configuration.new.tap do |config|
        config.access_token = api_key
        config.debugging = false
      end
    end
  end
end
