begin
  require "csv"
rescue LoadError
  warn "[INFO] Gem 'csv' não encontrada. Instalando..."
  system("gem install csv") or abort("Falha ao instalar gem 'csv'.")
  require "csv"
end

require "faker"

Dir.mkdir("dados") unless Dir.exist?("dados")

NUM_CATEGORIAS = (ENV["NUM_CATEGORIAS"] || 50).to_i
CSV_FILE = "dados/dados_grande.csv"

Faker::UniqueGenerator.clear

CSV.open(CSV_FILE, "w") do |csv|
  csv << ["Categoria", "Valor"]
  NUM_CATEGORIAS.times do
    categoria = Faker::Company.unique.name
    valor = rand(10..200)
    csv << [categoria, valor]
  end
end

puts "CSV gerado em #{CSV_FILE} com #{NUM_CATEGORIAS} categorias."