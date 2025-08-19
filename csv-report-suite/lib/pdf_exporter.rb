
require "prawn"
require "prawn/table"
require "gruff"
require "tempfile"
require_relative "./utils"

module CsvReportSuite
  class PdfExporter
    # rows is array of hashes (symbolized)
    def self.render(rows, title: "Relatório", category_key: :category, amount_keys: [:amount, :valor, :price, :preco])
      headers = rows.flat_map(&:keys).uniq
      table = [headers] + rows.map { |r| headers.map { |h| r[h] } }

      # Build totals per category (for pie chart)
      grouped = rows.group_by { |r| r[category_key] || "Outros" }
      totals = grouped.transform_values do |arr|
        arr.sum do |r|
          amount_keys.map { |k| r[k].to_f if r[k] }.compact.first.to_f
        end
      end

      # Pie chart with Gruff
      chart_file = Tempfile.new(["chart", ".png"])
      begin
        g = Gruff::Pie.new
        g.title = "Distribuição por Categoria"
        totals.each { |k, v| g.data(k.to_s, v) }
        g.write(chart_file.path)

        Prawn::Document.new(page_size: "A4", margin: 36) do |pdf|
          pdf.text title, size: 22, style: :bold, align: :center
          pdf.move_down 10
          pdf.text "Gerado em: #{Time.now.strftime("%d/%m/%Y %H:%M:%S")}", size: 9, align: :center
          pdf.move_down 16

          pdf.table(table, header: true,
                    row_colors: ["F5F7FB", "FFFFFF"],
                    cell_style: { size: 9 }) do |t|
            t.row(0).font_style = :bold
            t.row(0).background_color = "DCE2F0"
          end

          total = Utils.total_amount(rows)
          if total > 0
            pdf.move_down 12
            pdf.text "Total: R$ #{'%.2f' % total}", size: 12, style: :bold
          end

          pdf.start_new_page
          pdf.text "Gráfico", style: :bold
          pdf.move_down 8
          pdf.image chart_file.path, fit: [500, 400], position: :center
        end.render
      ensure
        chart_file.close!
      end
    end
  end
end
