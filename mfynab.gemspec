# frozen_string_literal: true

require_relative "lib/mfynab/version"

Gem::Specification.new do |spec|
  spec.name = "mfynab"
  spec.version = MFYNAB::VERSION
  spec.authors = ["David Stosik"]
  spec.email = ["david.stosik+git-noreply@gmail.com"]

  spec.summary = "Sync transaction history from MoneyForward to YNAB."
  spec.description = "Sync transaction history from MoneyForward to YNAB."
  spec.homepage = "https://github.com/davidstosik/moneyforward_ynab"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  # spec.metadata["allowed_push_host"] = "Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/davidstosik/moneyforward_ynab"
  spec.metadata["changelog_uri"] = "https://github.com/davidstosik/moneyforward_ynab/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir["lib/**/*.rb"] + Dir["exe/*"]

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "csv"
  spec.add_dependency "ferrum", "~> 0.15"
  spec.add_dependency "psych"
  spec.add_dependency "ynab", "~> 3.4"
end
