require "prawn"
require "prawn/table"
require "tempfile"

# Try to load gruff, continue without it if ImageMagick is not available
begin
  require "gruff"
  GRUFF_AVAILABLE = true
rescue LoadError => e
  GRUFF_AVAILABLE = false
  warn "Warning: Gruff not available (#{e.message}). Charts will be disabled."
end

module CsvReportSuite
  class PdfExporter
    def self.render(rows, title: "Relatório", category_key: :category, amount_keys: [:amount, :valor, :price, :preco])
      return "" if rows.nil? || rows.empty?
      
      headers = rows.flat_map(&:keys).uniq.map(&:to_s)
      table_data = [headers] + rows.map { |row| headers.map { |h| format_cell_value(row[h.to_sym]) } }

      # Calculate totals for numeric columns
      totals = calculate_totals(rows, amount_keys)
      
      # Build category totals for pie chart
      category_totals = build_category_totals(rows, category_key, amount_keys)

      generate_pdf(table_data, title, totals, category_totals)
    end

    private

    def self.generate_pdf(table_data, title, totals, category_totals)
      chart_file = nil
      
      begin
        # Create pie chart if gruff is available and we have category data
        if GRUFF_AVAILABLE && category_totals.any? && category_totals.values.any? { |v| v > 0 }
          chart_file = create_pie_chart(category_totals)
        end

        Prawn::Document.new(page_size: "A4", margin: 36) do |pdf|
          # Header
          pdf.text title, size: 22, style: :bold, align: :center
          pdf.move_down 10
          pdf.text "Gerado em: #{Time.now.strftime('%d/%m/%Y %H:%M:%S')}", size: 9, align: :center
          pdf.move_down 16

          # Data table
          if table_data.size > 1 # Has data beyond headers
            pdf.table(table_data, header: true,
                      row_colors: ["F5F7FB", "FFFFFF"],
                      cell_style: { size: 9, padding: 4 }) do |table|
              table.row(0).font_style = :bold
              table.row(0).background_color = "DCE2F0"
              table.column_widths = calculate_column_widths(table_data, pdf.bounds.width)
            end
          else
            pdf.text "Nenhum dado encontrado para exibir.", size: 12, style: :italic
          end

          # Totals summary
          if totals.any?
            pdf.move_down 20
            pdf.text "Resumo dos Totais:", size: 14, style: :bold
            pdf.move_down 8
            
            totals.each do |field, total|
              pdf.text "#{field.to_s.capitalize}: R$ #{'%.2f' % total}", size: 12
            end
          end

          # Add pie chart if available
          if chart_file
            pdf.start_new_page
            pdf.text "Distribuição por Categoria", size: 16, style: :bold, align: :center
            pdf.move_down 20
            
            begin
              pdf.image chart_file.path, fit: [500, 400], position: :center
            rescue => e
              pdf.text "Erro ao carregar gráfico: #{e.message}", size: 10, style: :italic
            end
          end
        end.render
      ensure
        chart_file&.close!
      end
    end

    def self.create_pie_chart(category_totals)
      chart_file = Tempfile.new(["chart", ".png"])
      
      g = Gruff::Pie.new(600)
      g.title = "Distribuição por Categoria"
      g.title_font_size = 18
      g.legend_font_size = 12
      
      # Add data to chart
      category_totals.each do |category, value|
        g.data(category.to_s, value) if value > 0
      end
      
      g.write(chart_file.path)
      chart_file
    rescue => e
      warn "Warning: Could not create pie chart: #{e.message}"
      chart_file&.close!
      nil
    end

    def self.calculate_totals(rows, amount_keys)
      totals = {}
      
      amount_keys.each do |key|
        total = rows.sum do |row|
          value = row[key]
          numeric_value(value)
        end
        
        totals[key] = total if total > 0
      end
      
      totals
    end

    def self.build_category_totals(rows, category_key, amount_keys)
      category_totals = Hash.new(0)
      
      rows.each do |row|
        category = row[category_key] || "Outros"
        amount = amount_keys.sum { |key| numeric_value(row[key]) }
        category_totals[category] += amount
      end
      
      category_totals
    end

    def self.numeric_value(value)
      return 0.0 if value.nil? || value.to_s.strip.empty?
      
      # Handle Brazilian decimal format
      normalized = value.to_s.gsub(',', '.')
      Float(normalized)
    rescue ArgumentError
      0.0
    end

    def self.format_cell_value(value)
      return "" if value.nil?
      
      # Format numbers with Brazilian locale
      if numeric_value(value) != 0.0
        num = numeric_value(value)
        if num.abs >= 1
          "%.2f" % num
        else
          value.to_s
        end
      else
        value.to_s
      end
    end

    def self.calculate_column_widths(table_data, total_width)
      return {} if table_data.empty?
      
      num_columns = table_data.first.size
      base_width = (total_width - 20) / num_columns
      
      # Create a hash with column widths
      widths = {}
      (0...num_columns).each { |i| widths[i] = base_width }
      widths
    end
  end
end