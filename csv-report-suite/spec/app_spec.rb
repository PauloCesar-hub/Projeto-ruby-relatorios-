require_relative 'spec_helper'

RSpec.describe CsvReportSuite::App do
  describe "GET /" do
    it "returns the main page" do
      get '/'
      expect(last_response).to be_ok
      expect(last_response.body).to include('Suite de Relatórios')
      expect(last_response.body).to include('Gerar relatório')
    end
  end

  describe "GET /health" do
    it "returns health status as JSON" do
      get '/health'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')
      
      json = JSON.parse(last_response.body)
      expect(json['status']).to eq('ok')
      expect(json['version']).to eq(CsvReportSuite::VERSION)
      expect(json['timestamp']).to be_a(String)
    end
  end

  describe "GET /nonexistent" do
    it "returns 404 error page" do
      get '/nonexistent'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to include('Erro 404')
      expect(last_response.body).to include('Página não encontrada')
    end
  end

  describe "POST /export/csv" do
    context "with valid CSV file" do
      let(:csv_content) { "date,category,amount\n2023-01-01,Food,25.50\n2023-01-02,Transport,15.00" }
      
      it "exports CSV data successfully" do
        post '/export/csv', {
          file: Rack::Test::UploadedFile.new(
            StringIO.new(csv_content), 
            'text/csv', 
            original_filename: 'test.csv'
          ),
          type: 'expenses'
        }
        
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('text/csv')
        expect(last_response.headers['Content-Disposition']).to include('attachment')
        expect(last_response.headers['Content-Disposition']).to include('relatorio_expenses')
        
        # Check CSV content uses semicolon delimiter
        expect(last_response.body).to include(';')
      end
    end

    context "with valid JSON file" do
      let(:json_content) do
        [
          { "date" => "2023-01-01", "categoria" => "Food", "valor" => 25.50 },
          { "date" => "2023-01-02", "categoria" => "Transport", "valor" => 15.00 }
        ].to_json
      end
      
      it "exports JSON data successfully" do
        post '/export/csv', {
          file: Rack::Test::UploadedFile.new(
            StringIO.new(json_content), 
            'application/json', 
            original_filename: 'test.json'
          ),
          type: 'expenses'
        }
        
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('text/csv')
      end
    end

    context "with field selection" do
      let(:csv_content) { "date,category,amount,description\n2023-01-01,Food,25.50,Lunch\n2023-01-02,Transport,15.00,Bus" }
      
      it "exports only selected fields" do
        post '/export/csv', {
          file: Rack::Test::UploadedFile.new(
            StringIO.new(csv_content), 
            'text/csv', 
            original_filename: 'test.csv'
          ),
          type: 'expenses', 
          fields: 'date,amount'
        }
        
        expect(last_response).to be_ok
        lines = last_response.body.split("\n")
        headers = lines.first.split(';').map { |h| h.gsub('"', '') }
        expect(headers).to include('date', 'amount')
        expect(headers).not_to include('category', 'description')
      end
    end

    context "with date filtering" do
      let(:csv_content) do
        "date,category,amount\n" \
        "2023-01-01,Food,25.50\n" \
        "2023-01-15,Transport,15.00\n" \
        "2023-02-01,Food,30.00"
      end
      
      it "filters data by date range" do
        post '/export/csv', {
          file: Rack::Test::UploadedFile.new(
            StringIO.new(csv_content), 
            'text/csv', 
            original_filename: 'test.csv'
          ),
          type: 'expenses', 
          from: '2023-01-01', 
          to: '2023-01-31'
        }
        
        expect(last_response).to be_ok
        expect(last_response.body).to include('2023-01-01')
        expect(last_response.body).to include('2023-01-15')
        expect(last_response.body).not_to include('2023-02-01')
      end
    end

    context "without file or URL" do
      it "returns 400 error" do
        post '/export/csv', { type: 'expenses' }
        
        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Erro 400')
      end
    end
  end

  describe "POST /export/pdf" do
    context "with valid data" do
      let(:csv_content) { "date,category,amount\n2023-01-01,Food,25.50\n2023-01-02,Transport,15.00" }
      
      it "exports PDF data successfully" do
        post '/export/pdf', {
          file: Rack::Test::UploadedFile.new(
            StringIO.new(csv_content), 
            'text/csv', 
            original_filename: 'test.csv'
          ),
          type: 'expenses'
        }
        
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/pdf')
        expect(last_response.headers['Content-Disposition']).to include('attachment')
        expect(last_response.headers['Content-Disposition']).to include('relatorio_expenses')
        
        # Check it's actually a PDF
        expect(last_response.body).to start_with('%PDF')
      end
    end
  end

  describe "POST /export/xlsx" do
    context "with valid data" do
      let(:csv_content) { "date,category,amount\n2023-01-01,Food,25.50\n2023-01-02,Transport,15.00" }
      
      it "exports XLSX data successfully" do
        post '/export/xlsx', {
          file: Rack::Test::UploadedFile.new(
            StringIO.new(csv_content), 
            'text/csv', 
            original_filename: 'test.csv'
          ),
          type: 'expenses'
        }
        
        expect(last_response).to be_ok
        expect(last_response.content_type).to include('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')
        expect(last_response.headers['Content-Disposition']).to include('attachment')
        expect(last_response.headers['Content-Disposition']).to include('relatorio_expenses')
        
        # Check it's actually a ZIP file (XLSX format)
        expect(last_response.body).to start_with('PK')
      end
    end
  end

  describe "Error handling" do
    context "with invalid file format" do
      it "returns 400 error for unsupported format" do
        post '/export/csv', {
          file: Rack::Test::UploadedFile.new(
            StringIO.new('invalid content'), 
            'text/plain', 
            original_filename: 'test.txt'
          ),
          type: 'expenses'
        }
        
        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Erro 400')
      end
    end

    context "with malformed JSON" do
      it "returns 400 error for malformed JSON" do
        post '/export/csv', {
          file: Rack::Test::UploadedFile.new(
            StringIO.new('{ invalid json }'), 
            'application/json', 
            original_filename: 'test.json'
          ),
          type: 'expenses'
        }
        
        expect(last_response.status).to eq(400)
        expect(last_response.body).to include('Erro 400')
      end
    end
  end
end