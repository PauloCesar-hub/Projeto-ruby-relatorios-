
module CsvReportSuite
  class ReportGenerator
    attr_reader :rows
    def initialize(rows)
      @rows = (rows || []).map { |r| r.transform_keys { |k| k.to_sym } }
    end

    def group_by(field, sum_field: nil)
      return self if field.nil? || field.to_s.strip.empty?
      f = field.to_sym; s = sum_field && !sum_field.empty? ? sum_field.to_sym : nil
      grouped = @rows.group_by { |r| r[f] }
      result = grouped.map do |key, arr|
        total = s ? arr.sum { |r| (r[s] || r[s.to_s.to_sym] || 0).to_f } : nil
        row = { f => key }
        row[:total] = total unless total.nil?
        row
      end
      @rows = result
      self
    end

    def chart_series(group_field, sum_field)
      return [[], []] if group_field.nil? || sum_field.nil?
      f = group_field.to_sym; s = sum_field.to_sym
      totals = Hash.new(0.0)
      @rows.each { |r| totals[r[f]] += (r[s] || 0).to_f }
      [totals.keys.map(&:to_s), totals.values]
    end
  end
end
