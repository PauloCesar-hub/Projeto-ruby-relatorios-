# -*- encoding: utf-8 -*-
# stub: gruff 0.29.0 ruby lib

Gem::Specification.new do |s|
  s.name = "gruff".freeze
  s.version = "0.29.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.metadata = { "bug_tracker_uri" => "https://github.com/topfunky/gruff/issues", "changelog_uri" => "https://github.com/topfunky/gruff/blob/master/CHANGELOG.md", "rubygems_mfa_required" => "true" } if s.respond_to? :metadata=
  s.require_paths = ["lib".freeze]
  s.authors = ["Geoffrey Grosenbach".freeze, "Uwe Kubosch".freeze]
  s.date = "1980-01-02"
  s.description = "Beautiful graphs for one or multiple datasets. Can be used on websites or in documents.".freeze
  s.email = "boss@topfunky.com".freeze
  s.homepage = "https://github.com/topfunky/gruff".freeze
  s.licenses = ["MIT".freeze]
  s.required_ruby_version = Gem::Requirement.new(">= 3.0.0".freeze)
  s.rubygems_version = "3.4.20".freeze
  s.summary = "Beautiful graphs for one or multiple datasets.".freeze

  s.installed_by_version = "3.4.20" if s.respond_to? :installed_by_version

  s.specification_version = 4

  s.add_runtime_dependency(%q<rmagick>.freeze, [">= 5.5"])
  s.add_runtime_dependency(%q<bigdecimal>.freeze, [">= 3.0"])
  s.add_runtime_dependency(%q<histogram>.freeze, [">= 0"])
end
