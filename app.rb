# app.rb
require "sinatra/base"
require "json"
require "cgi"
require "time"
require "tempfile"
begin
  require "zip" # rubyzip
rescue LoadError
  warn "[WARN] gem 'rubyzip' não encontrada. Instale com: gem install rubyzip"
end
begin
  require "rufus-scheduler"
rescue LoadError
  warn "[WARN] gem 'rufus-scheduler' não encontrada. Instale com: gem install rufus-scheduler"
end
begin
  require "axlsx"
rescue LoadError
  warn "[WARN] gem 'axlsx' não encontrada. Rota /export.xlsx ficará indisponível até instalar: gem install axlsx"
end
begin
  require "pony"
rescue LoadError
  warn "[WARN] gem 'pony' não encontrada. E-mails desativados até instalar: gem install pony"
end

# Seu gerador de relatórios — mantenha o arquivo em lib/report_generator.rb
require_relative "./lib/report_generator"

module CsvReportSuite
  class App < Sinatra::Base
    ROOT = File.expand_path(__dir__)
    set :bind, "0.0.0.0"
    set :port, (ENV["PORT"] || 8080).to_i
    set :public_folder, File.join(ROOT, "public")
    set :views, File.join(ROOT, "views")
    set :server, :webrick
    enable :sessions

    PER_PAGE = 10

    configure do
      puts "[BOOT] Sinatra iniciando em #{Time.now} ROOT=#{ROOT}"
      set :generator, CsvReportSuite::ReportGenerator.new(base_dir: ROOT)
      puts "[BOOT] Gerador pronto. dados=#{settings.generator.dados_dir}"

      if defined?(Rufus::Scheduler)
        every = ENV["SCHEDULE_EVERY"] || "10m"
        settings.scheduler = Rufus::Scheduler.new
        settings.scheduler.every every do
          begin
            settings.generator.process_all
          rescue => e
            settings.generator.logs << "[Scheduler] Erro: #{e.class}: #{e.message}"
          end
        end
        puts "[BOOT] Scheduler ativo a cada #{every}"
      end
    end

    helpers do
      def generator = settings.generator

      def sanitize_filename(name)
        name.to_s.gsub(/[^\w.\-]/, "_")
      end

      def report_paths(csv_file)
        base = File.basename(csv_file, ".csv")
        graph = File.join(generator.graficos_dir, "grafico_#{base}.png")
        pdf   = File.join(generator.relatorios_dir, "relatorio_#{base}.pdf")
        [graph, pdf]
      end

      def flash_messages
        msgs = session.delete(:flash)
        return [] unless msgs && !msgs.empty?
        msgs
      end

      def add_flash(msg, type = :info)
        session[:flash] ||= []
        session[:flash] << { text: msg, type: type }
      end

      def human_alert_class(sym)
        case sym.to_s
        when "success" then "success"
        when "error"   then "danger"
        when "warn"    then "warning"
        else "info"
        end
      end

      def rel_path(path)
        # converte caminho absoluto p/ relativo com base no ROOT/public
        p = Pathname.new(path).expand_path
        pub = Pathname.new(settings.public_folder).expand_path
        if p.to_s.start_with?(pub.to_s)
          p.to_s.sub(pub.to_s + "/", "")
        else
          # se não estiver em public, servir via route /file?path=...
          nil
        end
      end

      def page_params
        q = params["q"].to_s.strip
        page = params["page"].to_i
        page = 1 if page < 1
        [q, page]
      end

      def csv_items(filter_q: "")
        all = Dir.glob(File.join(generator.dados_dir, "*.csv")).sort
        return all if filter_q.to_s.empty?
        all.select { |f| File.basename(f).downcase.include?(filter_q.downcase) }
      end

      def csv_status(csv_path)
        g, p = report_paths(csv_path)
        {
          graph: File.exist?(g),
          pdf: File.exist?(p)
        }
      end
    end

    before do
      cache_control :no_store
      # content_type "text/html" # Sinatra define automaticamente para ERB
    end

    get "/" do
      q, page = page_params
      files = csv_items(filter_q: q)
      total = files.size
      total_pages = (total.to_f / PER_PAGE).ceil
      page = [[page, 1].max, [total_pages, 1].max].min
      start_index = (page - 1) * PER_PAGE
      @csv_files = files.slice(start_index, PER_PAGE) || []

      @q = q
      @page = page
      @total_pages = total_pages
      @show_logs = params["logs"] == "1"
      @flashes = flash_messages
      erb :index
    end

    get "/diag" do
      content_type "text/plain"
      [
        "Ruby: #{RUBY_VERSION}",
        "ROOT: #{ROOT}",
        "PWD: #{Dir.pwd}",
        "dados_dir: #{generator.dados_dir}",
        "graficos_dir: #{generator.graficos_dir}",
        "relatorios_dir: #{generator.relatorios_dir}",
        "CSV files: #{Dir.glob(File.join(generator.dados_dir, '*.csv')).size}",
        "Graficos: #{Dir.glob(File.join(generator.graficos_dir, '*.png')).size}",
        "Relatorios: #{Dir.glob(File.join(generator.relatorios_dir, '*.pdf')).size}",
        "Logs (ultimos 5):",
        *generator.logs.last(5)
      ].join("\n")
    end

    get "/dashboard" do
      stats = {
        csv: Dir.glob(File.join(generator.dados_dir, "*.csv")).size,
        graphs: Dir.glob(File.join(generator.graficos_dir, "*.png")).size,
        pdfs: Dir.glob(File.join(generator.relatorios_dir, "*.pdf")).size
      }
      @stats_json = JSON.dump(stats)
      erb :dashboard
    end

    get "/admin" do
      q = params["q"].to_s.strip
      from = params["from"]
      to = params["to"]
      status = params["status"]

      files = csv_items(filter_q: q)
      files = files.select do |f|
        ok = true
        if from && !from.empty?
          ok &&= File.mtime(f) >= Time.parse(from) rescue ok
        end
        if to && !to.empty?
          ok &&= File.mtime(f) <= Time.parse(to) rescue ok
        end
        if status && status != "all"
          st = csv_status(f)
          ready = st[:graph] && st[:pdf]
          ok &&= (status == "done" ? ready : !ready)
        end
        ok
      end

      @files = files.map { |f|
        st = csv_status(f)
        {
          name: File.basename(f),
          mtime: File.mtime(f),
          size: File.size(f),
          graph: st[:graph],
          pdf: st[:pdf]
        }
      }
      erb :admin
    end

    get "/download_all" do
      unless defined?(Zip)
        halt 503, "Dependência ausente: instale a gem 'rubyzip'"
      end
      content_type "application/zip"
      attachment "relatorios.zip"
      temp_zip = Tempfile.new("relatorios.zip")
      Zip::File.open(temp_zip.path, Zip::File::CREATE) do |zip|
        Dir.glob(File.join(generator.graficos_dir, "*.png")).each do |f|
          zip.add("graficos/#{File.basename(f)}", f) if File.file?(f)
        end
        Dir.glob(File.join(generator.relatorios_dir, "*.pdf")).each do |f|
          zip.add("relatorios/#{File.basename(f)}", f) if File.file?(f)
        end
      end
      send_file temp_zip.path, type: "application/zip"
    ensure
      temp_zip.close! if temp_zip
    end

    get "/export.xlsx" do
      unless defined?(Axlsx)
        halt 503, "Dependência ausente: instale a gem 'axlsx'"
      end
      pkg = Axlsx::Package.new
      wb = pkg.workbook
      wb.add_worksheet(name: "Relatórios") do |sheet|
        sheet.add_row ["Arquivo", "Modificado em", "Tamanho (bytes)", "Gráfico", "PDF"]
        Dir.glob(File.join(generator.dados_dir, "*.csv")).sort.each do |f|
          st = csv_status(f)
          sheet.add_row [
            File.basename(f),
            File.mtime(f).strftime("%Y-%m-%d %H:%M:%S"),
            File.size(f),
            st[:graph] ? "OK" : "pendente",
            st[:pdf] ? "OK" : "pendente"
          ]
        end
      end
      content_type "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      attachment "relatorios.xlsx"
      tmp = Tempfile.new(["relatorios", ".xlsx"])
      pkg.serialize(tmp.path)
      send_file tmp.path
    ensure
      tmp.close! if tmp
    end

    post "/send_mail" do
      unless defined?(Pony)
        halt 503, "Dependência ausente: instale a gem 'pony'"
      end
      file = params["file"]
      halt 400, "Informe ?file=nome.csv" unless file
      base = File.basename(file, ".csv")
      pdf = File.join(generator.relatorios_dir, "relatorio_#{base}.pdf")
      halt 404, "PDF não encontrado" unless File.exist?(pdf)

      Pony.mail(
        to: ENV["MAIL_TO"] || halt(400, "Defina MAIL_TO"),
        from: ENV["MAIL_FROM"] || "no-reply@example.com",
        subject: "Relatório #{base}",
        body: "Segue relatório em anexo.",
        attachments: { File.basename(pdf) => File.read(pdf) },
        via: :smtp,
        via_options: {
          address: ENV["SMTP_ADDRESS"] || "smtp.gmail.com",
          port: (ENV["SMTP_PORT"] || 587).to_i,
          user_name: ENV["SMTP_USER"] || halt(400, "Defina SMTP_USER"),
          password: ENV["SMTP_PASS"] || halt(400, "Defina SMTP_PASS"),
          authentication: :plain,
          enable_starttls_auto: true
        }
      )
      add_flash "E-mail enviado para #{ENV['MAIL_TO']}", :success
      redirect "/"
    end

    before "/api/*" do
      content_type "application/json"
    end

    get "/api/health" do
      JSON.dump(ok: true, time: Time.now.to_s)
    end

    get "/api/stats" do
      stats = {
        csv: Dir.glob(File.join(generator.dados_dir, "*.csv")).size,
        graphs: Dir.glob(File.join(generator.graficos_dir, "*.png")).size,
        pdfs: Dir.glob(File.join(generator.relatorios_dir, "*.pdf")).size
      }
      JSON.dump(stats)
    end

    get "/api/files" do
      kind = params["type"] || "all"
      list = []
      if kind == "all" || kind == "csv"
        Dir.glob(File.join(generator.dados_dir, "*.csv")).each do |f|
          st = csv_status(f)
          list << { kind: "csv", name: File.basename(f), mtime: File.mtime(f), size: File.size(f), status: st }
        end
      end
      if kind == "all" || kind == "graphs"
        Dir.glob(File.join(generator.graficos_dir, "*.png")).each do |f|
          list << { kind: "graph", name: File.basename(f), mtime: File.mtime(f), size: File.size(f) }
        end
      end
      if kind == "all" || kind == "pdfs"
        Dir.glob(File.join(generator.relatorios_dir, "*.pdf")).each do |f|
          list << { kind: "pdf", name: File.basename(f), mtime: File.mtime(f), size: File.size(f) }
        end
      end
      JSON.dump(files: list.sort_by { |h| h[:name] })
    end

    get "/api/file/:kind/:name" do
      kind = params["kind"]
      name = sanitize_filename(params["name"])
      base_dir =
        case kind
        when "csv" then generator.dados_dir
        when "graph" then generator.graficos_dir
        when "pdf" then generator.relatorios_dir
        else halt 400, JSON.dump(error: "kind inválido")
        end
      path = File.join(base_dir, File.basename(name))
      halt 404, JSON.dump(error: "arquivo não encontrado") unless File.exist?(path)
      send_file path
    end

    post "/api/upload" do
      unless params[:file]&.[](:tempfile)
        halt 400, JSON.dump(error: "Arquivo não enviado")
      end
      filename = sanitize_filename(params[:file][:filename])
      dest = File.join(generator.dados_dir, filename)
      File.open(dest, "wb") { |f| f.write(params[:file][:tempfile].read) }
      if params[:process] == "on" || params[:process] == "true"
        generator.process_file(dest)
      end
      JSON.dump(status: "ok", file: filename)
    end

    post "/api/process" do
      file = params["file"] || (request.media_type =~ /json/ ? (JSON.parse(request.body.read)["file"] rescue nil) : nil)
      halt 400, JSON.dump(error: "Arquivo não informado") unless file
      path = File.join(generator.dados_dir, File.basename(file))
      halt 404, JSON.dump(error: "Arquivo não existe: #{file}") unless File.exist?(path)
      generator.process_file(path)
      JSON.dump(status: "processed", file: File.basename(file))
    end

    post "/api/process_all" do
      generator.process_all
      JSON.dump(status: "batch_scheduled")
    end

    post "/upload" do
      unless params[:file]&.[](:tempfile)
        add_flash "Arquivo não enviado.", :error
        redirect "/"
      end
      filename = sanitize_filename(params[:file][:filename])
      dest = File.join(generator.dados_dir, filename)
      File.open(dest, "wb") { |f| f.write(params[:file][:tempfile].read) }
      add_flash "Upload OK: #{filename}", :success
      if params[:process] == "on"
        generator.process_file(dest)
        add_flash "Processado: #{filename}", :success
      end
      redirect "/"
    end

    post "/process" do
      file = params[:file]
      if file.nil? || file.strip.empty?
        add_flash "Arquivo não informado.", :error
        redirect "/"
      end
      path = File.join(generator.dados_dir, File.basename(file))
      unless File.exist?(path)
        add_flash "Arquivo não existe: #{file}", :error
        redirect "/"
      end
      generator.process_file(path)
      add_flash "Processado: #{file}", :success
      redirect "/"
    end

    post "/process_all" do
      generator.process_all
      add_flash "Processamento em lote solicitado.", :info
      redirect "/"
    end

    get "/force_process" do
      file = params[:file]
      halt 400, "Use ?file=nome.csv" unless file
      path = File.join(generator.dados_dir, File.basename(file))
      halt 404, "Arquivo não existe" unless File.exist?(path)
      generator.process_file(path)
      "OK. Veja /?logs=1"
    end

    # Serve qualquer arquivo que esteja fora de public (somente leitura) - uso seguro
    get "/file" do
      path = params["path"]
      halt 400, "Informe path" unless path
      full = File.expand_path(path, settings.root)
      allowed = [generator.dados_dir, generator.graficos_dir, generator.relatorios_dir].map { |d| File.expand_path(d) }
      unless allowed.any? { |d| full.start_with?(d + File::SEPARATOR) || full == d }
        halt 403, "Acesso negado"
      end
      halt 404, "Arquivo não encontrado" unless File.exist?(full)
      send_file full
    end

    not_found do
      erb :not_found
    end

    error do
      "Erro interno: #{env['sinatra.error']&.message}"
    end

    # start app if executed directly
    run! if app_file == $0
  end
end
