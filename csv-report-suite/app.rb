
require "sinatra/base"
require "json"
require_relative "lib/csv_report_suite/version"
require_relative "lib/csv_report_suite/data_loader"
require_relative "lib/csv_report_suite/report_generator"
require_relative "lib/csv_report_suite/pdf_exporter"
require_relative "lib/csv_report_suite/xlsx_exporter"

module CsvReportSuite
  class App < Sinatra::Base
    configure do
      set :public_folder, File.expand_path("public", __dir__)
      set :views, File.expand_path("views", __dir__)
      enable :logging
      set :show_exceptions, false
    end

    configure :development do
      require "sinatra/reloader"
      register Sinatra::Reloader
    end

    # Routes
    get "/" do
      erb :index
    end

    get "/health" do
      content_type :json
      {
        status: "ok",
        version: CsvReportSuite::VERSION,
        timestamp: Time.now.iso8601
      }.to_json
    end

    post "/export/csv" do
      begin
        type, fields, from, to, rows = read_rows(params)
        csv = CsvReportSuite::ReportGenerator.generate(rows, type: type, fields: fields, from: from, to: to)
        
        content_type "text/csv; charset=utf-8"
        attachment "relatorio_#{type}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.csv"
        body csv
      rescue => e
        logger.error "CSV Export Error: #{e.message}"
        handle_error(e)
      end
    end

    post "/export/pdf" do
      begin
        type, fields, from, to, rows = read_rows(params)
        normalized = CsvReportSuite::ReportGenerator.normalize_rows(rows, type)
        filtered = CsvReportSuite::ReportGenerator.apply_date_filter(normalized, from: from, to: to)
        
        if fields && !fields.empty?
          filtered = CsvReportSuite::ReportGenerator.apply_field_selection(filtered, fields)
        end
        
        pdf = CsvReportSuite::PdfExporter.render(filtered, title: "Relatório #{type.to_s.capitalize}")
        
        content_type "application/pdf"
        attachment "relatorio_#{type}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.pdf"
        body pdf
      rescue => e
        logger.error "PDF Export Error: #{e.message}"
        handle_error(e)
      end
    end

    post "/export/xlsx" do
      begin
        type, fields, from, to, rows = read_rows(params)
        normalized = CsvReportSuite::ReportGenerator.normalize_rows(rows, type)
        filtered = CsvReportSuite::ReportGenerator.apply_date_filter(normalized, from: from, to: to)
        
        if fields && !fields.empty?
          filtered = CsvReportSuite::ReportGenerator.apply_field_selection(filtered, fields)
        end
        
        xlsx = CsvReportSuite::XlsxExporter.render(filtered, sheet_name: "Relatório #{type.to_s.capitalize}")
        
        content_type "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        attachment "relatorio_#{type}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.xlsx"
        body xlsx
      rescue => e
        logger.error "XLSX Export Error: #{e.message}"
        handle_error(e)
      end
    end

    # Error handlers
    error 400 do
      erb :error, locals: { 
        error_code: 400, 
        error_message: "Solicitação inválida. Verifique os dados enviados.",
        error_details: env['sinatra.error']&.message
      }
    end

    error 500 do
      erb :error, locals: { 
        error_code: 500, 
        error_message: "Erro interno do servidor. Tente novamente mais tarde.",
        error_details: settings.development? ? env['sinatra.error']&.message : nil
      }
    end

    not_found do
      erb :error, locals: { 
        error_code: 404, 
        error_message: "Página não encontrada.",
        error_details: nil
      }
    end

    # Helper methods
    helpers do
      def read_rows(params)
        type = (params[:type] || "expenses").to_sym
        fields = parse_fields(params[:fields])
        from = params[:from]
        to = params[:to]

        rows = if params[:file] && params[:file][:tempfile]
          CsvReportSuite::DataLoader.from_file(params[:file])
        elsif params[:url] && !params[:url].to_s.strip.empty?
          CsvReportSuite::DataLoader.from_api(params[:url])
        else
          halt 400, "Envie um arquivo (.csv/.json) ou informe uma URL de API."
        end

        if rows.nil? || rows.empty?
          halt 400, "Nenhum dado encontrado no arquivo ou URL fornecida."
        end

        [type, fields, from, to, rows]
      end

      def parse_fields(fields_param)
        return [] unless fields_param && !fields_param.strip.empty?
        
        fields_param.split(",").map(&:strip).reject(&:empty?)
      end

      def handle_error(error)
        case error
        when ArgumentError, StandardError
          halt 400, erb(:error, locals: { 
            error_code: 400, 
            error_message: "Erro ao processar dados: #{error.message}",
            error_details: settings.development? ? error.backtrace&.first(5)&.join("\n") : nil
          })
        else
          halt 500, erb(:error, locals: { 
            error_code: 500, 
            error_message: "Erro interno do servidor.",
            error_details: settings.development? ? error.message : nil
          })
        end
      end

      def h(text)
        Rack::Utils.escape_html(text)
      end
    end
  end
end
