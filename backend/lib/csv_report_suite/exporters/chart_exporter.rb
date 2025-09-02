
module CsvReportSuite
  module Exporters
    class ChartExporter
      def self.export(rows, path, group_field=nil, sum_field=nil)
        labels = rows.map { |r| r.keys.first.to_s }
        values = rows.map { |r| r[:total] || r.values[1].to_f }
        svg = %Q{<svg xmlns="http://www.w3.org/2000/svg" width="800" height="300"><rect width="100%" height="100%" fill="white"/>}
        values.each_with_index do |v,i|
          x = 50 + i*60
          h = (v / (values.max || 1).to_f) * 200
          y = 250 - h
          svg += %Q{<rect x="#{x}" y="#{y}" width="40" height="#{h}" fill="#0d6efd"/>}
          svg += %Q{<text x="#{x+20}" y="270" text-anchor="middle">#{labels[i]}</text>}
        end
        svg += "</svg>"
        File.write(path, svg)
        path
      end
    end
  end
end
