require "caxlsx"

module CsvReportSuite
  class XlsxExporter
    def self.render(rows, sheet_name: "Relatório", category_key: :category, amount_keys: [:amount, :valor, :price, :preco])
      return "" if rows.nil? || rows.empty?
      
      headers = rows.flat_map(&:keys).uniq.map(&:to_s)
      numeric_columns = detect_numeric_columns(rows, headers)
      date_columns = detect_date_columns(rows, headers)
      
      package = Axlsx::Package.new
      
      package.workbook.add_worksheet(name: sheet_name) do |sheet|
        styles = create_styles(package.workbook.styles)
        
        # Add headers with styling
        sheet.add_row(headers, style: styles[:header])
        
        # Add data rows
        rows.each do |row|
          formatted_row = headers.map do |header|
            value = row[header.to_sym]
            format_cell_value(value, header, numeric_columns, date_columns)
          end
          
          row_styles = headers.map do |header|
            if numeric_columns.include?(header)
              styles[:currency]
            elsif date_columns.include?(header)
              styles[:date]
            else
              styles[:text]
            end
          end
          
          sheet.add_row(formatted_row, style: row_styles)
        end
        
        # Add totals summary
        add_totals_summary(sheet, rows, headers, numeric_columns, styles)
        
        # Add category summary chart if possible
        add_category_chart(sheet, rows, category_key, amount_keys, styles)
        
        # Auto-fit columns
        sheet.column_widths(*calculate_column_widths(headers, rows))
      end
      
      package.to_stream.read
    end

    private

    def self.create_styles(styles_collection)
      {
        header: styles_collection.add_style(
          b: true, 
          bg_color: "DCE2F0", 
          alignment: { horizontal: :center, vertical: :center }
        ),
        currency: styles_collection.add_style(
          num_fmt: 8, # Brazilian currency format
          alignment: { horizontal: :right }
        ),
        date: styles_collection.add_style(
          num_fmt: 14, # Date format
          alignment: { horizontal: :center }
        ),
        text: styles_collection.add_style(
          alignment: { horizontal: :left }
        ),
        total_label: styles_collection.add_style(
          b: true,
          bg_color: "F0F0F0",
          alignment: { horizontal: :right }
        ),
        total_value: styles_collection.add_style(
          b: true,
          bg_color: "F0F0F0",
          num_fmt: 8,
          alignment: { horizontal: :right }
        )
      }
    end

    def self.detect_numeric_columns(rows, headers)
      sample_size = [rows.size, 10].min
      sample_rows = rows.first(sample_size)
      
      numeric_columns = []
      
      headers.each do |header|
        numeric_count = sample_rows.count do |row|
          value = row[header.to_sym]
          numeric_value?(value)
        end
        
        # Consider column numeric if >70% of values are numeric
        if numeric_count.to_f / sample_size > 0.7
          numeric_columns << header
        end
      end
      
      numeric_columns
    end

    def self.detect_date_columns(rows, headers)
      sample_size = [rows.size, 5].min
      sample_rows = rows.first(sample_size)
      
      date_columns = []
      
      headers.each do |header|
        date_count = sample_rows.count do |row|
          value = row[header.to_sym]
          date_value?(value)
        end
        
        # Consider column a date if >50% of values are dates
        if date_count.to_f / sample_size > 0.5
          date_columns << header
        end
      end
      
      date_columns
    end

    def self.add_totals_summary(sheet, rows, headers, numeric_columns, styles)
      return if numeric_columns.empty?
      
      # Add empty row for separation
      sheet.add_row([])
      
      # Add totals for each numeric column
      numeric_columns.each do |column|
        total = calculate_column_total(rows, column.to_sym)
        if total > 0
          sheet.add_row(
            ["TOTAL #{column.upcase}", total],
            style: [styles[:total_label], styles[:total_value]]
          )
        end
      end
    end

    def self.add_category_chart(sheet, rows, category_key, amount_keys, styles)
      category_totals = build_category_totals(rows, category_key, amount_keys)
      return if category_totals.empty? || category_totals.values.all?(&:zero?)
      
      # Add empty rows for separation
      sheet.add_row([])
      sheet.add_row([])
      
      # Add chart data
      chart_start_row = sheet.rows.size + 1
      sheet.add_row(["Categoria", "Valor"], style: [styles[:header], styles[:header]])
      
      category_totals.each do |category, total|
        sheet.add_row([category.to_s, total], style: [styles[:text], styles[:currency]])
      end
      
      chart_end_row = sheet.rows.size
      
      # Add pie chart
      sheet.add_chart(Axlsx::Pie3DChart, start_at: [0, chart_end_row + 1], end_at: [6, chart_end_row + 15]) do |chart|
        chart.add_series(
          data: sheet["B#{chart_start_row + 1}:B#{chart_end_row}"],
          labels: sheet["A#{chart_start_row + 1}:A#{chart_end_row}"]
        )
        chart.title = "Distribuição por Categoria"
      end
    rescue => e
      # Chart creation failed, continue without it
      warn "Warning: Could not create chart in XLSX: #{e.message}"
    end

    def self.calculate_column_total(rows, column_key)
      rows.sum { |row| numeric_value(row[column_key]) }
    end

    def self.build_category_totals(rows, category_key, amount_keys)
      category_totals = Hash.new(0)
      
      rows.each do |row|
        category = row[category_key] || "Outros"
        amount = amount_keys.sum { |key| numeric_value(row[key]) }
        category_totals[category] += amount if amount > 0
      end
      
      category_totals
    end

    def self.format_cell_value(value, header, numeric_columns, date_columns)
      return nil if value.nil? || value.to_s.strip.empty?
      
      if numeric_columns.include?(header)
        numeric_value(value)
      elsif date_columns.include?(header)
        parse_date(value)
      else
        value.to_s
      end
    end

    def self.numeric_value(value)
      return 0.0 if value.nil? || value.to_s.strip.empty?
      
      # Handle Brazilian decimal format
      normalized = value.to_s.gsub(',', '.')
      Float(normalized)
    rescue ArgumentError
      0.0
    end

    def self.numeric_value?(value)
      return false if value.nil? || value.to_s.strip.empty?
      
      normalized = value.to_s.gsub(',', '.')
      Float(normalized)
      true
    rescue ArgumentError
      false
    end

    def self.date_value?(value)
      return false if value.nil? || value.to_s.strip.empty?
      
      parse_date(value) != nil
    end

    def self.parse_date(value)
      return nil if value.nil? || value.to_s.strip.empty?
      
      # Try common date formats
      formats = ["%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d", "%d-%m-%Y"]
      
      formats.each do |format|
        begin
          return Date.strptime(value.to_s, format)
        rescue ArgumentError
          next
        end
      end
      
      # Fallback to Date.parse
      begin
        Date.parse(value.to_s)
      rescue ArgumentError
        nil
      end
    end

    def self.calculate_column_widths(headers, rows)
      # Calculate optimal column widths based on content
      widths = headers.map do |header|
        max_length = [header.length, 10].max # Minimum width
        
        # Sample some rows to estimate width
        sample_rows = rows.first(5)
        sample_rows.each do |row|
          value_length = row[header.to_sym].to_s.length
          max_length = [max_length, value_length].max
        end
        
        # Cap maximum width to reasonable size
        [max_length * 1.2, 50].min
      end
      
      widths
    end
  end
end