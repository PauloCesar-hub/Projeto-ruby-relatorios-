require "csv"
require "prawn"
require_relative "chart/bar_chart"

module CsvReportSuite
  class ReportGenerator
    attr_reader :base_dir, :dados_dir, :graficos_dir, :relatorios_dir, :logs

    def initialize(base_dir: nil)
      # base_dir pode ser passado ou deduzido (pasta do projeto = um nível acima de lib/)
      @base_dir = base_dir || File.expand_path("..", __dir__)
      @dados_dir      = File.join(@base_dir, "dados")
      @graficos_dir   = File.join(@base_dir, "graficos")
      @relatorios_dir = File.join(@base_dir, "relatorios")
      @logs = []
      ensure_directories
      log "ReportGenerator inicializado base_dir=#{@base_dir}"
    end

    def log(msg)
      stamp = Time.now.strftime("%H:%M:%S")
      line = "[#{stamp}] #{msg}"
      puts line
      @logs << line
      @logs.shift while @logs.size > 800
      line
    end

    def process_all
      files = Dir.glob(File.join(@dados_dir, "*.csv"))
      if files.empty?
        log "Nenhum CSV encontrado em #{@dados_dir}"
        return
      end
      files.each { |csv| process_file(csv) }
    end

    def process_file(csv_file)
      # Permite passar só o nome
      if !File.exist?(csv_file)
        candidate = File.join(@dados_dir, File.basename(csv_file))
        csv_file = candidate if File.exist?(candidate)
      end

      unless File.file?(csv_file)
        log "Arquivo não encontrado: #{csv_file}"
        return
      end

      log "Processando: #{csv_file}"
      data = read_csv(csv_file)
      if data.empty?
        log "CSV vazio / inválido: #{csv_file}"
        return
      end

      base_name = File.basename(csv_file, ".csv")
      graph_png = File.join(@graficos_dir, "grafico_#{base_name}.png")
      pdf_file  = File.join(@relatorios_dir, "relatorio_#{base_name}.pdf")

      generate_chart(data, graph_png)
      generate_pdf(data, base_name, graph_png, pdf_file)

      if File.exist?(graph_png)
        log "Gerado gráfico: #{relative_path(graph_png)}"
      else
        log "Falha ao gerar gráfico esperado: #{graph_png}"
      end
      if File.exist?(pdf_file)
        log "Gerado PDF: #{relative_path(pdf_file)}"
      else
        log "Falha ao gerar PDF esperado: #{pdf_file}"
      end
    rescue => e
      log "ERRO: #{e.class} - #{e.message}"
      log e.backtrace.first(6).join(" | ")
    end

    def relative_path(path)
      # Normaliza separadores para evitar falhas em Windows
      root = @base_dir.end_with?(File::SEPARATOR) ? @base_dir : @base_dir + File::SEPARATOR
      path.sub(root, "")
    end

    private

    def ensure_directories
      [@dados_dir, @graficos_dir, @relatorios_dir].each do |d|
        Dir.mkdir(d) unless Dir.exist?(d)
      end
    end

    def read_csv(path)
      data = []
      CSV.foreach(path, headers: true, encoding: "bom|utf-8") do |row|
        next if row.nil?
        h = row.to_h
        # Pega colunas tolerando variação de nome
        cat = (h["Categoria"] || h["categoria"] || row[0]).to_s.strip
        val_raw = (h["Valor"] || h["valor"] || row[1]).to_s.strip
        next if cat.empty? || val_raw.empty?
        val = begin
                Float(val_raw)
              rescue
                nil
              end
        next if val.nil?
        data << { categoria: cat, valor: val }
      end
      data
    end

    def generate_chart(data, output)
      categories = data.map { |d| d[:categoria] }
      values     = data.map { |d| d[:valor] }
      CsvReportSuite::Chart::BarChart.new(
        categories: categories,
        values: values,
        output_path: output
      ).render
    end

    def generate_pdf(data, base_name, chart_path, output_pdf)
      Prawn::Document.generate(output_pdf) do
        text "Relatório de Dados - #{base_name}", size: 24, style: :bold
        move_down 15

        if File.exist?(chart_path)
            text "Gráfico de valores por categoria:"
            move_down 8
            image chart_path, width: 480
            move_down 15
        else
            text "Gráfico não encontrado (#{chart_path})", color: "FF0000"
            move_down 10
        end

        text "Tabela de dados:", style: :bold
        move_down 8
        table_data = [["Categoria", "Valor"]] + data.map { |d| [d[:categoria], d[:valor]] }
        table(table_data, header: true,
                          row_colors: %w[F0F0F0 FFFFFF],
                          width: bounds.width)
      end
    end
  end
end

begin
  require "csv"
rescue LoadError
  warn "[INFO] Gem 'csv' não encontrada. Instalando..."
  system("gem install csv") or abort("Falha ao instalar gem 'csv'. Rode manualmente: gem install csv")
  require "csv"
end
