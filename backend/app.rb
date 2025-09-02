require 'sinatra/base'
require 'sinatra/json'
require 'fileutils'
require 'csv'
require 'prawn'
require 'caxlsx'

class ReportAPI < Sinatra::Base
  set :protection, except: :http_origin
  set :public_folder, File.expand_path('public', __dir__)
  set :uploads_dir, File.expand_path('public/uploads', __dir__)

  configure { FileUtils.mkdir_p(settings.uploads_dir) }

  before do
    headers 'Access-Control-Allow-Origin' => '*',
            'Access-Control-Allow-Methods' => 'GET,POST,OPTIONS',
            'Access-Control-Allow-Headers' => 'Content-Type, Authorization'
    content_type :json if request.path_info.start_with?('/api/')
  end

  options '*' do
    200
  end

  helpers do
    def save_upload(file_param)
      halt 400, json(message: 'arquivo não enviado') unless file_param
      filename = File.basename(file_param[:filename]).gsub(/\s/, '_')
      path = File.join(settings.uploads_dir, filename)
      File.open(path, 'wb') { |f| f.write(file_param[:tempfile].read) }
      [filename, path]
    end

    def read_csv_safe(path)
      CSV.read(path, headers: true, header_converters: :symbol, liberal_parsing: true).map(&:to_hash)
    rescue CSV::MalformedCSVError
      halt 400, json(message: 'CSV malformado')
    end
  end

  # Upload CSV
  post '/api/upload' do
    filename, path = save_upload(params[:file])
    rows = read_csv_safe(path)
    fields = rows.first ? rows.first.keys.map(&:to_s) : []
    preview = rows.first(20)
    json message: 'ok', file: filename, fields: fields, preview: preview, size: File.size(path)
  end

  # Gerar série para gráfico
  get '/api/series' do
    file = params[:file]
    group = params[:group]
    sum = params[:sum]
    halt 400, json(message: 'parâmetros inválidos') if file.nil? || group.nil? || sum.nil?

    path = File.join(settings.uploads_dir, File.basename(file))
    halt 404, json(message: 'arquivo não encontrado') unless File.exist?(path)

    rows = read_csv_safe(path)
    totals = Hash.new(0.0)
    g, s = group.to_sym, sum.to_sym
    rows.each { |r| totals[r[g]] += (r[s] || 0).to_f if r[g] }

    json labels: totals.keys.map(&:to_s), values: totals.values
  end

  # Gerar relatório (CSV, XLSX, PDF)
  post '/api/report' do
    file_param = params[:file]
    fmt = (params[:format] || 'csv').downcase

    # Aceita upload ou apenas nome de arquivo
    path = if file_param.is_a?(Hash) && file_param[:tempfile]
             save_upload(file_param)[1]
           elsif file_param.is_a?(String)
             File.join(settings.uploads_dir, File.basename(file_param))
           else
             halt 400, json(message: 'arquivo inválido')
           end

    halt 404, json(message: 'arquivo não encontrado') unless File.exist?(path)

    rows = read_csv_safe(path)
    outname = File.basename(path, '.*') + ".#{fmt}"
    outpath = File.join(settings.uploads_dir, outname)

    case fmt
    when 'csv'
      CSV.open(outpath, 'w') { |csv| csv << rows.first.keys if rows.first; rows.each { |r| csv << r.values } }
    when 'xlsx'
      pkg = Axlsx::Package.new
      wb = pkg.workbook
      wb.add_worksheet(name: 'Dados') do |sheet|
        sheet.add_row(rows.first.keys) if rows.first
        rows.each { |r| sheet.add_row(r.values) }
      end
      pkg.serialize(outpath)
    when 'pdf'
      Prawn::Document.generate(outpath) do |pdf|
        pdf.text 'Relatório', size: 18, style: :bold
        pdf.move_down 10
        if rows.first
          data = [rows.first.keys.map(&:to_s)] + rows.map { |r| r.values.map(&:to_s) }
          pdf.table(data, header: true)
        else
          pdf.text 'Sem dados'
        end
      end
    else
      halt 400, json(message: 'formato inválido')
    end

    json message: 'ok', download_url: "/uploads/#{outname}"
  end

  # Baixar arquivos
  get '/uploads/:name' do |name|
    file = File.join(settings.uploads_dir, name)
    halt 404, json(message: 'not found') unless File.exist?(file)
    send_file file
  end

  run! if app_file == $0
end
