
require 'prawn'
require 'prawn/table'
module CsvReportSuite
  module Exporters
    class PDFExporter
      def self.export(rows, filename, save_dir: nil)
        raise 'no rows' if rows.nil? || rows.empty?
        headers = rows.first.keys.map(&:to_s)
        data = [headers] + rows.map { |r| headers.map { |h| r[h.to_sym] || r[h] } }
        path = filename
        path = File.join(save_dir, filename) if save_dir
        FileUtils.mkdir_p(File.dirname(path))
        Prawn::Document.generate(path) do |pdf|
          pdf.text 'Relatório', size: 16, style: :bold, align: :center
          pdf.move_down 10
          pdf.table(data, header: true) { |t| t.row(0).font_style = :bold }
        end
        path
      end
    end
  end
end
