
require "axlsx"
require_relative "./utils"

module CsvReportSuite
  class XlsxExporter
    def self.render(rows, sheet_name: "Relatório", category_key: :category, amount_keys: [:amount, :valor, :price, :preco])
      headers = rows.flat_map(&:keys).uniq
      Axlsx::Package.new do |p|
        p.workbook.add_worksheet(name: sheet_name) do |sheet|
          styles = p.workbook.styles
          header_style = styles.add_style(b: true, bg_color: "DCE2F0", alignment: { horizontal: :center })
          money_style = styles.add_style(num_fmt: 5) # Brazilian currency style approximation

          sheet.add_row headers, style: header_style
          rows.each do |r|
            sheet.add_row headers.map { |h| r[h] }
          end

          total = Utils.total_amount(rows)
          if total > 0
            sheet.add_row []
            sheet.add_row ["TOTAL", total], style: [header_style, money_style]
          end

          # Totals for pie chart
          grouped = rows.group_by { |r| r[category_key] || "Outros" }
          categories = grouped.keys
          amounts = grouped.map do |_, arr|
            arr.sum { |r| amount_keys.map { |k| r[k].to_f if r[k] }.compact.first.to_f }
          end

          # Put data for chart
          chart_start_row = sheet.rows.size + 2
          sheet.add_row ["Categoria", "Valor"], style: header_style
          categories.each_with_index do |c, i|
            sheet.add_row [c, amounts[i]]
          end

          # Create the pie chart
          last_row = sheet.rows.size
          sheet.add_chart(Axlsx::Pie3DChart, start_at: [0, last_row + 1], end_at: [6, last_row + 20]) do |chart|
            chart.add_series data: sheet["B#{chart_start_row+1}:B#{last_row}"], labels: sheet["A#{chart_start_row+1}:A#{last_row}"]
            chart.title = "Distribuição por Categoria"
          end
        end
      end.to_stream.read
    end
  end
end
