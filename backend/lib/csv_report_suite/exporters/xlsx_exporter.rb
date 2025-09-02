
require 'caxlsx'
module CsvReportSuite
  module Exporters
    class XLSXExporter
      def self.export(rows, filename)
        raise 'no rows' if rows.nil? || rows.empty?
        headers = rows.first.keys.map(&:to_s)
        pkg = Axlsx::Package.new
        wb = pkg.workbook
        wb.add_worksheet(name: 'Report') do |sheet|
          sheet.add_row headers
          rows.each { |r| sheet.add_row headers.map { |h| r[h.to_sym] || r[h] } }
        end
        pkg.serialize(filename)
        filename
      end
    end
  end
end
