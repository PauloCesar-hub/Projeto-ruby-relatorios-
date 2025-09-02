
require 'csv'
module CsvReportSuite
  module Exporters
    class CSVExporter
      def self.export(rows, path)
        raise 'no rows' if rows.nil? || rows.empty?
        headers = rows.first.keys.map(&:to_s)
        CSV.open(path, 'wb') do |csv|
          csv << headers
          rows.each { |r| csv << headers.map { |h| r[h.to_sym] || r[h] } }
        end
        path
      end
    end
  end
end
