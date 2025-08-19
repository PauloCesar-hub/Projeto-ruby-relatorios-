
require "sinatra"
require "csv"
require "prawn"
require "prawn/table"
require "gruff"
require "axlsx"
configure :development do
  require "sinatra/reloader"
end

module CsvReportSuite
  class App < Sinatra::Base
    configure do
      set :public_folder, File.expand_path("public", __dir__)
      set :views, File.expand_path("views", __dir__)
      enable :logging
    end

    configure :development do
      register Sinatra::Reloader
    end

    get "/" do
      erb :index
    end

    helpers do
      def read_rows(params)
        type = (params[:type] || "expenses").to_sym
        fields = (params[:fields] || "").split(",").map { |s| s.strip }.reject(&:empty?)
        from = params[:from]
        to = params[:to]

        rows = if params[:file] && params[:file][:tempfile]
          CsvReportSuite::DataLoader.from_file(params[:file])
        elsif params[:url] && !params[:url].to_s.strip.empty?
          CsvReportSuite::DataLoader.from_api(params[:url])
        else
          halt 400, "Envie um arquivo (.csv/.json) ou informe uma URL de API."
        end

        [type, fields, from, to, rows]
      end
    end

    post "/export/csv" do
      type, fields, from, to, rows = read_rows(params)
      csv = CsvReportSuite::ReportGenerator.generate(rows, type: type, fields: fields, from: from, to: to)
      content_type "text/csv"
      attachment "relatorio_#{type}.csv"
      body csv
    end

    post "/export/pdf" do
      type, fields, from, to, rows = read_rows(params)
      # Normalize before exporting to ensure consistent columns
      normalized = CsvReportSuite::ReportGenerator.normalize_rows(rows, type)
      normalized = CsvReportSuite::ReportGenerator.apply_date_filter(normalized, from: from, to: to)
      pdf = CsvReportSuite::PdfExporter.render(normalized, title: "Relatório #{type.to_s.capitalize}")
      content_type "application/pdf"
      attachment "relatorio_#{type}.pdf"
      body pdf
    end

    post "/export/xlsx" do
      type, fields, from, to, rows = read_rows(params)
      normalized = CsvReportSuite::ReportGenerator.normalize_rows(rows, type)
      normalized = CsvReportSuite::ReportGenerator.apply_date_filter(normalized, from: from, to: to)
      xlsx = CsvReportSuite::XlsxExporter.render(normalized, sheet_name: "Relatório #{type.to_s.capitalize}")
      content_type "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
      attachment "relatorio_#{type}.xlsx"
      body xlsx
    end
  end
end
