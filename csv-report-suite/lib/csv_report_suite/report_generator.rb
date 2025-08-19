require "csv"
require "date"

module CsvReportSuite
  class ReportGenerator
    # Portuguese synonyms for field mapping
    EXPENSE_FIELDS = {
      date: [:date, :data, :created_at, :timestamp, :fecha],
      category: [:category, :categoria, :type, :tipo, :class, :classe],
      description: [:description, :descricao, :desc, :name, :nome, :titulo, :title],
      amount: [:amount, :valor, :price, :preco, :value, :cost, :custo, :total]
    }.freeze

    NOTE_FIELDS = {
      date: [:date, :data, :created_at, :timestamp, :fecha],
      title: [:title, :titulo, :name, :nome, :subject, :assunto],
      text: [:text, :conteudo, :content, :body, :corpo, :description, :descricao],
      tags: [:tags, :etiquetas, :labels, :categories, :categorias]
    }.freeze

    def self.generate(rows, type:, fields: [], from: nil, to: nil)
      normalized = normalize_rows(rows, type)
      filtered = apply_date_filter(normalized, from: from, to: to)
      selected = apply_field_selection(filtered, fields)
      
      # Use semicolon delimiter as specified in requirements
      CSV.generate(col_sep: ';', force_quotes: true) do |csv|
        if selected.any?
          headers = selected.first.keys
          csv << headers.map(&:to_s)
          selected.each { |row| csv << headers.map { |h| format_value(row[h]) } }
        end
      end
    end

    def self.normalize_rows(rows, type)
      return [] if rows.nil? || rows.empty?
      
      field_mapping = case type.to_sym
      when :expenses, :invoices then EXPENSE_FIELDS
      when :notes then NOTE_FIELDS
      else {}
      end

      rows.map do |row|
        normalized = {}
        
        # Apply field mapping with Portuguese synonyms
        field_mapping.each do |target_field, source_fields|
          value = source_fields.find { |sf| !row[sf].nil? && row[sf].to_s.strip != "" }
          normalized[target_field] = row[value] if value
        end
        
        # Merge with original data, normalized fields take precedence
        row.merge(normalized)
      end
    end

    def self.apply_date_filter(rows, from:, to:)
      return rows unless from || to
      
      start_date = from && parse_date(from)
      end_date = to && parse_date(to)
      
      return rows unless start_date || end_date
      
      rows.select do |row|
        row_date = extract_date_from_row(row)
        next true unless row_date
        
        valid = true
        valid &&= (row_date >= start_date) if start_date
        valid &&= (row_date <= end_date) if end_date
        valid
      end
    end

    def self.apply_field_selection(rows, fields)
      return rows if fields.nil? || fields.empty?
      
      selected_fields = fields.map(&:to_sym)
      rows.map do |row|
        selected_fields.each_with_object({}) do |field, hash|
          hash[field] = row[field] if row.key?(field)
        end
      end
    end

    def self.detect_numeric_columns(rows)
      return [] if rows.empty?
      
      sample_size = [rows.size, 10].min
      sample_rows = rows.first(sample_size)
      
      numeric_columns = []
      
      rows.first.keys.each do |key|
        numeric_count = sample_rows.count do |row|
          value = row[key]
          numeric_value?(value)
        end
        
        # Consider column numeric if >80% of values are numeric
        if numeric_count.to_f / sample_size > 0.8
          numeric_columns << key
        end
      end
      
      numeric_columns
    end

    private

    def self.parse_date(date_string)
      return nil unless date_string
      
      # Try multiple date formats
      formats = ["%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d", "%d-%m-%Y"]
      
      formats.each do |format|
        begin
          return Date.strptime(date_string.to_s, format)
        rescue ArgumentError
          next
        end
      end
      
      # Fallback to Date.parse
      begin
        Date.parse(date_string.to_s)
      rescue ArgumentError
        nil
      end
    end

    def self.extract_date_from_row(row)
      # Try common date field names
      date_fields = [:date, :data, :created_at, :timestamp, :fecha]
      
      date_fields.each do |field|
        if row[field]
          parsed = parse_date(row[field])
          return parsed if parsed
        end
      end
      
      nil
    end

    def self.numeric_value?(value)
      return false if value.nil? || value.to_s.strip.empty?
      
      # Handle Brazilian decimal format (comma as decimal separator)
      normalized = value.to_s.gsub(',', '.')
      
      # Check if it's a valid number
      Float(normalized)
      true
    rescue ArgumentError
      false
    end

    def self.format_value(value)
      return "" if value.nil?
      
      # Handle numeric values with Brazilian formatting if needed
      if numeric_value?(value)
        # Keep original formatting for CSV export
        value.to_s
      else
        value.to_s
      end
    end
  end
end