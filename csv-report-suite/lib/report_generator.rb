
require "csv"
require "date"

module CsvReportSuite
  class ReportGenerator
    def self.generate(rows, type:, fields: [], from: nil, to: nil)
      rows = normalize_rows(rows, type)
      rows = apply_date_filter(rows, from: from, to: to)
      headers = fields.empty? ? rows.flat_map(&:keys).uniq : fields.map(&:to_sym)

      CSV.generate(force_quotes: true) do |csv|
        csv << headers
        rows.each { |r| csv << headers.map { |h| r[h] } }
      end
    end

    def self.normalize_rows(rows, type)
      case type.to_sym
      when :expenses
        rows.map do |r|
          {
            date: (r[:date] || r[:data] || r[:created_at]),
            category: (r[:category] || r[:categoria]),
            description: (r[:description] || r[:descricao] || r[:desc]),
            amount: (r[:amount] || r[:valor] || r[:price] || r[:preco])
          }.merge(r)
        end
      when :notes
        rows.map do |r|
          {
            date: (r[:date] || r[:data] || r[:created_at]),
            title: (r[:title] || r[:titulo]),
            text: (r[:text] || r[:conteudo] || r[:content]),
            tags: (r[:tags] || r[:etiquetas])
          }.merge(r)
        end
      else
        rows
      end
    end

    def self.apply_date_filter(rows, from:, to:)
      f = from && Date.parse(from) rescue nil
      t = to && Date.parse(to) rescue nil
      return rows unless f || t
      rows.select do |r|
        d = r[:date] && Date.parse(r[:date].to_s) rescue nil
        next true unless d
        ok = true
        ok &&= (d >= f) if f
        ok &&= (d <= t) if t
        ok
      end
    end
  end
end
