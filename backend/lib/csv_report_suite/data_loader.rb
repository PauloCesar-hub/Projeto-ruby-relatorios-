
require 'csv'
module CsvReportSuite
  class DataLoader
    def self.load(input:)
      raise 'input required' if input.nil? || input.empty?
      raise "not found: #{input}" unless File.exist?(input)
      CSV.read(input, headers: true, header_converters: :symbol).map(&:to_hash)
    end
  end
end
