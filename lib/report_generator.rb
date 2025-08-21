# lib/report_generator.rb
require "csv"
require "fileutils"
require "gruff"
require "prawn"
require "axlsx"

module CsvReportSuite
  class ReportGenerator
    attr_reader :dados_dir, :graficos_dir, :relatorios_dir, :logs

    def initialize(base_dir:)
      @dados_dir = File.join(base_dir, "dados")
      @graficos_dir = File.join(base_dir, "graficos")
      @relatorios_dir = File.join(base_dir, "relatorios")
      @logs = []
      [@dados_dir, @graficos_dir, @relatorios_dir].each { |d| FileUtils.mkdir_p(d) }
    end

    def log(msg)
      puts "[LOG] #{msg}"
      @logs << "#{Time.now.strftime("%H:%M:%S")} - #{msg}"
    end

    # Processar um único CSV
    def process_file(path)
      log "Processando #{File.basename(path)}"
      data = CSV.read(path, headers: true)

      # Pegar colunas numéricas
      numeric_cols = data.headers.select do |h|
        data[h].compact.any? { |v| v =~ /^\d+(\.\d+)?$/ }
      end

      stats = {}
      numeric_cols.each do |col|
        values = data[col].compact.map(&:to_f)
        next if values.empty?
        stats[col] = {
          soma: values.sum,
          media: (values.sum / values.size).round(2),
          max: values.max,
          min: values.min
        }
      end

      base = File.basename(path, ".csv")

      # Gráfico
      if numeric_cols.any?
        g = Gruff::Line.new
        g.title = "Relatório: #{base}"
        numeric_cols.each do |col|
          g.data(col, data[col].map { |v| v.to_f })
        end
        g.write(File.join(@graficos_dir, "grafico_#{base}.png"))
      end

      # PDF
      Prawn::Document.generate(File.join(@relatorios_dir, "relatorio_#{base}.pdf")) do
        text "Relatório CSV: #{base}", size: 20, style: :bold
        move_down 20
        stats.each do |col, s|
          text "Coluna: #{col}"
          text " - Soma: #{s[:soma]}"
          text " - Média: #{s[:media]}"
          text " - Máx: #{s[:max]}"
          text " - Mín: #{s[:min]}"
          move_down 10
        end
      end

      # Excel
      Axlsx::Package.new do |p|
        p.workbook.add_worksheet(name: "Relatório") do |sheet|
          sheet.add_row ["Coluna", "Soma", "Média", "Máx", "Mín"]
          stats.each do |col, s|
            sheet.add_row [col, s[:soma], s[:media], s[:max], s[:min]]
          end
        end
        p.serialize(File.join(@relatorios_dir, "relatorio_#{base}.xlsx"))
      end

      log "Finalizado: #{base}"
    rescue => e
      log "Erro ao processar #{File.basename(path)}: #{e.message}"
    end

    # Processar todos os CSVs
    def process_all
      Dir.glob(File.join(@dados_dir, "*.csv")).each { |f| process_file(f) }
    end

    def relative_path(path)
      path.sub(/^#{Regexp.escape(File.expand_path("..", __dir__))}[\/\\]?/, "")
    end
  end
end
