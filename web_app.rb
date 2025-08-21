# web_app.rb – CSV Report Suite (UI++ + ZIP + API + Admin + Dashboard + Scheduler)
require "sinatra/base"
require "json"
require "cgi"
require "time"
require "tempfile"
begin
  require "zip" # rubyzip
rescue LoadError
  warn "[WARN] gem 'rubyzip' não encontrada. Instale com: gem install rubyzip  (ou bundle add rubyzip)"
end
begin
  require "rufus-scheduler"
rescue LoadError
  warn "[WARN] gem 'rufus-scheduler' não encontrada. Instale com: gem install rufus-scheduler  (ou bundle add rufus-scheduler)"
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

require_relative "./lib/report_generator"

module CsvReportSuite
  class App < Sinatra::Base
    ROOT = File.expand_path(__dir__)
    set :bind, "0.0.0.0"
    set :port, (ENV["PORT"] || 8080)
    set :public_folder, ROOT
    set :server, :webrick
    enable :sessions

    PER_PAGE = 10

    configure do
      puts "[BOOT] Sinatra iniciando em #{Time.now} ROOT=#{ROOT}"
      set :generator, CsvReportSuite::ReportGenerator.new(base_dir: ROOT)
      puts "[BOOT] Gerador pronto. dados=#{settings.generator.dados_dir}"

      # Inicia agendamento automático, se rufus-scheduler disponível
      if defined?(Rufus::Scheduler)
        every = ENV["SCHEDULE_EVERY"] || "10m"
        set :scheduler, Rufus::Scheduler.new
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
        name.gsub(/[^\w.\-]/, "_")
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
        generator.relative_path(path)
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
      content_type "text/html" if request.path_info == "/"
    end

    # Página principal (lista, busca, paginação, upload com barra, botões)
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

    # Diagnóstico rápido
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

    # Dashboard estatísticas
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

    # Upload (interface tradicional)
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

    # Processar 1
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

    not_found do
      "Rota não encontrada."
    end

    error do
      "Erro interno: #{env['sinatra.error'].message}"
    end

    template :layout do
      <<~ERB
      <!doctype html>
      <html lang="pt-BR" data-bs-theme="light">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title><%= @title || "CSV Report Suite" %></title>
          <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
          <style>
            .logs-box { background:#111; color:#ddd; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, "Liberation Mono", "Courier New", monospace; padding:12px; max-height:260px; overflow:auto; white-space: pre-wrap; border-radius: .5rem; }
            .file-cell a { word-break: break-all; }
          </style>
        </head>
        <body class="p-3 p-sm-4">
          <nav class="navbar navbar-expand-lg bg-body-tertiary rounded-3 mb-4 px-3">
            <a class="navbar-brand fw-semibold" href="/">CSV Report Suite</a>
            <div class="ms-auto d-flex gap-2">
              <a class="btn btn-outline-secondary btn-sm" target="_blank" href="/diag">Diagnóstico</a>
              <a class="btn btn-outline-secondary btn-sm" href="/dashboard">Dashboard</a>
              <a class="btn btn-outline-secondary btn-sm" href="/admin">Admin</a>
              <a class="btn btn-outline-primary btn-sm" href="/download_all">Baixar ZIP</a>
            </div>
          </nav>
          <main class="container-fluid">
            <% if @flashes && !@flashes.empty? %>
              <div class="mb-3">
                <% @flashes.each do |f| %>
                  <div class="alert alert-<%= human_alert_class(f[:type]) %> alert-dismissible fade show" role="alert">
                    <%= f[:text] %>
                    <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
                  </div>
                <% end %>
              </div>
            <% end %>
            <%= yield %>
          </main>
          <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
        </body>
      </html>
      ERB
    end

    template :index do
      <<~ERB
      <div class="row g-4">
        <div class="col-12 col-lg-4">
          <div class="card shadow-sm">
            <div class="card-body">
              <h5 class="card-title">Upload CSV</h5>
              <form id="uploadForm" action="/upload" method="post" enctype="multipart/form-data" class="vstack gap-2">
                <input class="form-control" type="file" name="file" required />
                <div class="form-check">
                  <input class="form-check-input" type="checkbox" name="process" id="process" checked>
                  <label class="form-check-label" for="process">Processar já</label>
                </div>
                <button id="uploadBtn" type="submit" class="btn btn-primary">Enviar</button>
                <div class="progress mt-2 d-none" id="uploadProgressWrap">
                  <div id="uploadProgress" class="progress-bar progress-bar-striped progress-bar-animated" role="progressbar" aria-valuemin="0" aria-valuemax="100" style="width: 0%;">0%</div>
                </div>
                <div class="small text-muted" id="uploadStatus"></div>
              </form>
            </div>
          </div>
          <% if @show_logs %>
            <div class="logs-box mt-3"><%= generator.logs.join("\\n") %></div>
          <% end %>
          <div class="mt-2">
            <a href="/?logs=1" class="small">Ver logs</a> |
            <a href="/" class="small">Ocultar logs</a>
          </div>
        </div>

        <div class="col-12 col-lg-8">
          <div class="card shadow-sm">
            <div class="card-body">
              <div class="d-flex flex-wrap gap-2 align-items-center mb-2">
                <form class="d-flex" role="search" method="get" action="/">
                  <input class="form-control me-2" type="search" placeholder="Buscar por nome..." aria-label="Buscar" name="q" value="<%= CGI.escapeHTML(@q.to_s) %>">
                  <button class="btn btn-outline-primary" type="submit">Buscar</button>
                </form>
                <form action="/process_all" method="post" class="ms-auto">
                  <button class="btn btn-secondary">Processar Todos</button>
                </form>
              </div>

              <div class="table-responsive">
                <table class="table table-sm align-middle">
                  <thead class="table-light">
                    <tr>
                      <th>CSV</th>
                      <th>Gráfico</th>
                      <th>PDF</th>
                      <th class="text-end">Ações</th>
                    </tr>
                  </thead>
                  <tbody>
                    <% if @csv_files.empty? %>
                      <tr><td colspan="4" class="text-center text-muted py-4">Nenhum CSV encontrado.</td></tr>
                    <% else %>
                      <% @csv_files.each do |csv| %>
                        <% graph, pdf = report_paths(csv) %>
                        <tr>
                          <td class="file-cell"><%= File.basename(csv) %><br><small class="text-muted"><%= File.mtime(csv).strftime("%Y-%m-%d %H:%M") %></small></td>
                          <td>
                            <% if File.exist?(graph) %>
                              <a class="btn btn-outline-success btn-sm" href="/<%= rel_path(graph) %>" target="_blank">Ver</a>
                            <% else %>
                              <span class="badge text-bg-secondary">pendente</span>
                            <% end %>
                          </td>
                          <td>
                            <% if File.exist?(pdf) %>
                              <a class="btn btn-outline-primary btn-sm" href="/<%= rel_path(pdf) %>" target="_blank">Baixar</a>
                            <% else %>
                              <span class="badge text-bg-secondary">pendente</span>
                            <% end %>
                          </td>
                          <td class="text-end">
                            <form class="d-inline" action="/process" method="post">
                              <input type="hidden" name="file" value="<%= File.basename(csv) %>" />
                              <button class="btn btn-primary btn-sm" type="submit">Processar</button>
                            </form>
                            <a class="btn btn-link btn-sm" href="/force_process?file=<%= File.basename(csv) %>">force</a>
                          </td>
                        </tr>
                      <% end %>
                    <% end %>
                  </tbody>
                </table>
              </div>

              <% if @total_pages > 1 %>
                <nav aria-label="Paginação">
                  <ul class="pagination justify-content-center">
                    <% prev_page = @page - 1 %>
                    <% next_page = @page + 1 %>
                    <li class="page-item <%= 'disabled' if @page <= 1 %>">
                      <a class="page-link" href="/?q=<%= CGI.escape(@q.to_s) %>&page=<%= prev_page %>">Anterior</a>
                    </li>
                    <% (1..@total_pages).each do |p| %>
                      <li class="page-item <%= 'active' if p == @page %>">
                        <a class="page-link" href="/?q=<%= CGI.escape(@q.to_s) %>&page=<%= p %>"><%= p %></a>
                      </li>
                    <% end %>
                    <li class="page-item <%= 'disabled' if @page >= @total_pages %>">
                      <a class="page-link" href="/?q=<%= CGI.escape(@q.to_s) %>&page=<%= next_page %>">Próxima</a>
                    </li>
                  </ul>
                </nav>
              <% end %>
            </div>
          </div>
        </div>
      </div>

      <script>
        // Upload com barra de progresso (XHR)
        const form = document.getElementById('uploadForm');
        const btn  = document.getElementById('uploadBtn');
        const wrap = document.getElementById('uploadProgressWrap');
        const bar  = document.getElementById('uploadProgress');
        const stat = document.getElementById('uploadStatus');
        if (form) {
          form.addEventListener('submit', function(e) {
            e.preventDefault();
            const formData = new FormData(form);
            const xhr = new XMLHttpRequest();
            xhr.open('POST', form.action, true);
            wrap.classList.remove('d-none');
            btn.disabled = true;
            stat.textContent = 'Enviando arquivo...';
            xhr.upload.onprogress = function(e) {
              if (e.lengthComputable) {
                const percent = Math.round((e.loaded / e.total) * 100);
                bar.style.width = percent + '%';
                bar.textContent = percent + '%';
                bar.setAttribute('aria-valuenow', percent);
              }
            };
            xhr.onreadystatechange = function() {
              if (xhr.readyState === 4) {
                if (xhr.status >= 200 && xhr.status < 400) {
                  stat.textContent = 'Upload concluído. Atualizando...';
                  window.location.href = '/';
                } else {
                  stat.textContent = 'Falha no upload: ' + (xhr.statusText || xhr.status);
                  btn.disabled = false;
                }
              }
            };
            xhr.send(formData);
          });
        }
      </script>
      ERB
    end

    template :dashboard do
      <<~ERB
      <% @title = "Dashboard" %>
      <div class="card shadow-sm">
        <div class="card-body">
          <h5 class="card-title">Estatísticas</h5>
          <p class="text-muted">Resumo dos artefatos gerados.</p>
          <div class="row row-cols-1 row-cols-md-3 g-3 mb-3">
            <% stats = JSON.parse(@stats_json) %>
            <div class="col"><div class="p-3 border rounded-3">CSVs: <strong><%= stats["csv"] %></strong></div></div>
            <div class="col"><div class="p-3 border rounded-3">Gráficos: <strong><%= stats["graphs"] %></strong></div></div>
            <div class="col"><div class="p-3 border rounded-3">PDFs: <strong><%= stats["pdfs"] %></strong></div></div>
          </div>
          <pre class="bg-light p-3 rounded-3"><%= @stats_json %></pre>
          <a class="btn btn-outline-secondary" href="/">Voltar</a>
        </div>
      </div>
      ERB
    end

    template :admin do
      <<~ERB
      <% @title = "Admin" %>
      <div class="card shadow-sm">
        <div class="card-body">
          <h5 class="card-title">Administração</h5>
          <form class="row g-3 mb-3" method="get" action="/admin">
            <div class="col-md-4">
              <label class="form-label">Busca</label>
              <input class="form-control" type="text" name="q" value="<%= CGI.escapeHTML(params['q'].to_s) %>" placeholder="Nome do arquivo">
            </div>
            <div class="col-md-3">
              <label class="form-label">De</label>
              <input class="form-control" type="datetime-local" name="from" value="<%= CGI.escapeHTML(params['from'].to_s) %>">
            </div>
            <div class="col-md-3">
              <label class="form-label">Até</label>
              <input class="form-control" type="datetime-local" name="to" value="<%= CGI.escapeHTML(params['to'].to_s) %>">
            </div>
            <div class="col-md-2">
              <label class="form-label">Status</label>
              <select class="form-select" name="status">
                <% current = (params['status'] || 'all') %>
                <option value="all" <%= 'selected' if current=='all' %>>Todos</option>
                <option value="pending" <%= 'selected' if current=='pending' %>>Pendentes</option>
                <option value="done" <%= 'selected' if current=='done' %>>Prontos</option>
              </select>
            </div>
            <div class="col-12 d-flex gap-2">
              <button class="btn btn-primary">Filtrar</button>
              <a class="btn btn-outline-secondary" href="/admin">Limpar</a>
            </div>
          </form>

          <div class="table-responsive">
            <table class="table table-sm align-middle">
              <thead class="table-light"><tr><th>Arquivo</th><th>Modificado</th><th>Tamanho</th><th>Gráfico</th><th>PDF</th></tr></thead>
              <tbody>
                <% if @files.empty? %>
                  <tr><td colspan="5" class="text-center text-muted py-4">Nenhum resultado.</td></tr>
                <% else %>
                  <% @files.each do |h| %>
                    <tr>
                      <td><%= h[:name] %></td>
                      <td><%= h[:mtime].strftime("%Y-%m-%d %H:%M") %></td>
                      <td><%= h[:size] %></td>
                      <td><%= h[:graph] ? "OK" : "-" %></td>
                      <td><%= h[:pdf] ? "OK" : "-" %></td>
                    </tr>
                  <% end %>
                <% end %>
              </tbody>
            </table>
          </div>
          <a class="btn btn-outline-secondary" href="/">Voltar</a>
        </div>
      </div>
      ERB
    end

  end # class App
end # module CsvReportSuite

CsvReportSuite::App.run! if __FILE__ == $0
