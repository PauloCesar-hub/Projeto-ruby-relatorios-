require "csv"
require "json"
require "net/http"
require "uri"

module CsvReportSuite
  class DataLoader
    def self.from_file(file)
      filename = file[:filename]
      tempfile = file[:tempfile]
      
      # Auto-detect format from content or extension
      ext = File.extname(filename).downcase
      content_type = file[:type] if file.respond_to?(:type)
      
      # Try to detect format from content type first, then extension
      format = detect_format(content_type, ext)
      
      case format
      when :csv then parse_csv(tempfile)
      when :json then parse_json(tempfile)
      else 
        raise ArgumentError, "Formato não suportado: #{ext}. Use .csv ou .json"
      end
    end

    def self.from_api(url_str)
      uri = URI.parse(url_str)
      res = Net::HTTP.get_response(uri)
      
      unless res.is_a?(Net::HTTPSuccess)
        raise "Falha ao buscar API: #{res.code} #{res.message}"
      end
      
      content_type = res['content-type']
      
      # Auto-detect JSON/CSV from Content-Type or heuristics
      if content_type&.include?('json') || res.body.strip.start_with?('{', '[')
        json = JSON.parse(res.body)
        rows = extract_json_data(json)
      elsif content_type&.include?('csv') || res.body.include?(',') || res.body.include?(';')
        rows = parse_csv_string(res.body)
      else
        # Try JSON first, fallback to CSV
        begin
          json = JSON.parse(res.body)
          rows = extract_json_data(json)
        rescue JSON::ParserError
          rows = parse_csv_string(res.body)
        end
      end
      
      symbolize_keys(rows)
    end

    private

    def self.detect_format(content_type, ext)
      if content_type&.include?('json') || ext == '.json'
        :json
      elsif content_type&.include?('csv') || ext == '.csv'
        :csv
      else
        :csv # Default fallback
      end
    end

    def self.parse_csv(io)
      io.rewind if io.respond_to?(:rewind)
      content = io.read
      parse_csv_string(content)
    end

    def self.parse_csv_string(content)
      # Auto-detect CSV delimiter
      delimiter = detect_csv_delimiter(content)
      
      rows = []
      CSV.parse(content, headers: true, col_sep: delimiter, 
                header_converters: ->(h) { normalize_header(h) }) do |row|
        rows << row.to_h.transform_keys(&:to_sym)
      end
      rows
    end

    def self.parse_json(io)
      io.rewind if io.respond_to?(:rewind)
      json = JSON.parse(io.read)
      extract_json_data(json)
    end

    def self.extract_json_data(json)
      rows = if json.is_a?(Array)
        json
      elsif json.is_a?(Hash) && json["data"].is_a?(Array)
        json["data"]
      elsif json.is_a?(Hash) && json["items"].is_a?(Array)
        json["items"]
      elsif json.is_a?(Hash) && json["results"].is_a?(Array)
        json["results"]
      else
        raise "Resposta JSON não suportada. Esperado Array ou { data: [], items: [], results: [] }"
      end
      
      symbolize_keys(rows)
    end

    def self.detect_csv_delimiter(content)
      # Look at the first few lines to detect delimiter
      sample_lines = content.lines.first(3).join
      
      # Count occurrences of potential delimiters
      delimiters = [',', ';', '\t', '|']
      counts = delimiters.map { |d| [d, sample_lines.count(d)] }
      
      # Return the delimiter with most occurrences, default to comma
      best_delimiter = counts.max_by { |_, count| count }&.first
      best_delimiter && best_delimiter != '\t' ? best_delimiter : ','
    end

    def self.normalize_header(str)
      str.to_s.strip.downcase.gsub(/\s+/, "_").gsub(/[^\w]/, "")
    end

    def self.symbolize_keys(obj)
      case obj
      when Array then obj.map { |v| symbolize_keys(v) }
      when Hash  then obj.transform_keys { |k| k.to_sym rescue k }.transform_values { |v| symbolize_keys(v) }
      else obj 
      end
    end
  end
end