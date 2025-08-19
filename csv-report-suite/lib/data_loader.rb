
require "csv"
require "json"
require "net/http"
require "uri"
require_relative "./utils"

module CsvReportSuite
  class DataLoader
    def self.from_file(file)
      filename = file[:filename]
      tempfile = file[:tempfile]
      ext = File.extname(filename).downcase
      case ext
      when ".csv" then parse_csv(tempfile)
      when ".json" then parse_json(tempfile)
      else raise ArgumentError, "Formato não suportado: #{ext}. Use .csv ou .json"
      end
    end

    def self.from_api(url_str)
      uri = URI.parse(url_str)
      res = Net::HTTP.get_response(uri)
      raise "Falha ao buscar API: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)
      json = JSON.parse(res.body)
      rows = if json.is_a?(Array)
        json
      elsif json.is_a?(Hash) && json["data"].is_a?(Array)
        json["data"]
      else
        raise "Resposta JSON não suportada. Esperado Array ou { data: [] }"
      end
      Utils.symbolize_keys(rows)
    end

    def self.parse_csv(io)
      rows = []
      csv = CSV.new(io, headers: true, header_converters: ->(h){ Utils.normalize_header(h) })
      csv.each { |row| rows << row.to_h.transform_keys(&:to_sym) }
      rows
    end

    def self.parse_json(io)
      json = JSON.parse(io.read)
      rows = if json.is_a?(Array)
        json
      elsif json.is_a?(Hash) && json["data"].is_a?(Array)
        json["data"]
      else
        raise "JSON não suportado. Esperado Array ou { data: [] }"
      end
      Utils.symbolize_keys(rows)
    end
  end
end
