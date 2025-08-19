
# CSV Report Suite

Uma aplicação web completa e modular baseada em Sinatra para geração de relatórios em múltiplos formatos (CSV, PDF, XLSX) a partir de dados CSV ou JSON.

## 🚀 Funcionalidades

- **Múltiplas fontes de dados**: Upload de arquivos (.csv/.json) ou ingestão via URL de API
- **Detecção automática**: Formato de arquivo (CSV/JSON) e delimitadores CSV
- **Normalização inteligente**: Mapeamento flexível de campos com sinônimos em português
- **Filtragem avançada**: Por intervalo de datas e seleção de campos específicos
- **Exportação em 3 formatos**:
  - **CSV**: Com delimitador ponto-e-vírgula
  - **PDF**: Tabelas formatadas com totais e gráficos opcionais (pizza)
  - **XLSX**: Planilhas estilizadas com formatação numérica/data e gráficos
- **Endpoint de saúde**: `/health` retorna JSON com status e versão
- **Tratamento robusto de erros**: Páginas de erro amigáveis e logs detalhados
- **Interface moderna**: JavaScript para downloads via fetch API
- **Suporte opcional a gráficos**: Gruff para gráficos de pizza (requer ImageMagick)

## 📁 Estrutura do Projeto

```
csv-report-suite/
├── app.rb                          # Aplicação principal Sinatra
├── config.ru                       # Configuração Rack/Puma
├── Gemfile                         # Dependências Ruby
├── Rakefile                        # Tarefas (server, spec)
├── lib/csv_report_suite/           # Módulos principais
│   ├── version.rb                  # Constante de versão
│   ├── data_loader.rb              # Ingestão CSV/JSON com auto-detecção
│   ├── report_generator.rb         # Normalização e filtragem
│   ├── pdf_exporter.rb             # Geração PDF com Prawn
│   └── xlsx_exporter.rb            # Geração XLSX com caxlsx
├── views/                          # Templates ERB
│   ├── layout.erb                  # Layout principal
│   ├── index.erb                   # Formulário interativo
│   └── error.erb                   # Página de erro
├── public/
│   ├── styles.css                  # Estilos CSS
│   └── samples/                    # Arquivos de exemplo
│       ├── expenses.csv
│       └── notes.json
└── spec/                           # Testes RSpec
    ├── spec_helper.rb
    └── app_spec.rb                 # Testes da aplicação
```

## 🛠 Instalação

### Pré-requisitos

- Ruby >= 3.1.0
- Bundler
- ImageMagick (opcional, para gráficos)

### Instalação no Ubuntu/Debian

```bash
# Instalar ImageMagick (opcional)
sudo apt-get update
sudo apt-get install imagemagick libmagickwand-dev

# Instalar dependências Ruby
bundle install
```

### Instalação no Windows

1. Instale o [ImageMagick](https://imagemagick.org/script/download.php#windows) (opcional)
2. Execute: `bundle install`

**Nota**: Se o ImageMagick não estiver disponível, a aplicação continuará funcionando sem gráficos, registrando um aviso no log.

## 🏃‍♂️ Uso

### Iniciar o servidor

```bash
# Usando Rake
bundle exec rake server

# Ou diretamente com Puma
bundle exec puma -p 4567
```

Acesse: http://localhost:4567

### Executar testes

```bash
# Todos os testes
bundle exec rspec

# Ou usando Rake
bundle exec rake spec
```

### Endpoints da API

- `GET /` - Interface web
- `GET /health` - Status da aplicação (JSON)
- `POST /export/csv` - Exportar CSV
- `POST /export/pdf` - Exportar PDF  
- `POST /export/xlsx` - Exportar XLSX

### Exemplo de uso via cURL

```bash
# Health check
curl http://localhost:4567/health

# Upload de arquivo
curl -X POST \
  -F "file=@expenses.csv" \
  -F "type=expenses" \
  -F "from=2023-01-01" \
  -F "to=2023-12-31" \
  http://localhost:4567/export/csv

# Ingestão via URL
curl -X POST \
  -F "url=https://api.exemplo.com/dados" \
  -F "type=expenses" \
  http://localhost:4567/export/pdf
```

## 📊 Tipos de Dados Suportados

### Despesas/Faturas (`expenses`/`invoices`)
Campos reconhecidos (com sinônimos em português):
- `date` / `data` / `created_at` / `timestamp`
- `category` / `categoria` / `type` / `tipo`
- `description` / `descricao` / `desc` / `name`
- `amount` / `valor` / `price` / `preco`

### Notas (`notes`)
Campos reconhecidos:
- `date` / `data` / `created_at`
- `title` / `titulo` / `name`
- `text` / `conteudo` / `content`
- `tags` / `etiquetas` / `labels`

## 🎨 Funcionalidades Avançadas

### Detecção Automática de Delimitadores CSV
A aplicação detecta automaticamente delimitadores (`,`, `;`, `\t`, `|`) analisando as primeiras linhas do arquivo.

### Parsing Defensivo
- **CSV**: Cabeçalhos normalizados, tratamento de diferentes delimitadores
- **JSON**: Suporte a arrays diretos ou objetos com `data`/`items`/`results`
- **Números**: Tolerante a separadores decimais com vírgula (formato brasileiro)

### Filtragem Inteligente
- **Datas**: Múltiplos formatos suportados (`YYYY-MM-DD`, `DD/MM/YYYY`, etc.)
- **Campos**: Seleção dinâmica com validação
- **Valores numéricos**: Detecção automática para totalizações

### Exportações Estilizadas

#### PDF (Prawn)
- Tabelas com cores alternadas
- Cabeçalhos destacados
- Totais automáticos por coluna numérica
- Gráficos de pizza opcionais (se Gruff disponível)
- Timestamp de geração

#### XLSX (caxlsx)
- Cabeçalhos com estilo
- Formatação automática (moeda, data, texto)
- Larguras de coluna otimizadas
- Totais com destaque visual
- Gráficos de pizza integrados

## 🧪 Testes

A suíte de testes cobre:
- ✅ Página principal e health endpoint
- ✅ Exportação CSV com dados válidos
- ✅ Exportação PDF e XLSX
- ✅ Filtragem por data e seleção de campos
- ✅ Tratamento de erros (formatos inválidos, JSON malformado)
- ✅ Validação de entrada (arquivo vs URL)

Execute com: `bundle exec rspec --format documentation`

## 🔧 Configuração e Customização

### Variáveis de Ambiente
- `RACK_ENV` - Ambiente (development/test/production)
- `PORT` - Porta do servidor (padrão: 4567)

### Logging
Em desenvolvimento, todos os logs são exibidos. Em produção, apenas erros críticos.

### Dependências Opcionais
- **gruff** - Gráficos (requer ImageMagick)
- **sinatra-reloader** - Recarga automática em desenvolvimento

## 🚀 Ideias para Futuras Melhorias

### Não Implementadas (Issues Futuras)
- **CLI wrapper** em `bin/` para uso headless
- **Cache e paginação** para datasets grandes
- **Streaming** de CSVs grandes
- **Exportadores adicionais**: JSON normalizado, HTML, endpoint só para gráficos
- **Validação de schema** de entrada
- **Campos calculados** definidos pelo usuário
- **Autenticação e autorização**
- **Rate limiting** para APIs públicas
- **Dockerização** para deploy

### Extensibilidade
O design modular facilita:
- Novos exportadores (herdar de classe base)
- Novos tipos de dados (adicionar ao `ReportGenerator`)
- Novos formatos de entrada (estender `DataLoader`)

## 📝 Contribuição

1. Fork do projeto
2. Crie uma branch para sua feature (`git checkout -b feature/nova-funcionalidade`)
3. Commit suas mudanças (`git commit -am 'Adiciona nova funcionalidade'`)
4. Push para a branch (`git push origin feature/nova-funcionalidade`)
5. Abra um Pull Request

## 📄 Licença

Este projeto está sob licença MIT. Veja o arquivo [LICENSE](LICENSE) para detalhes.

## 👥 Autor

Desenvolvido com ❤️ para demonstrar uma arquitetura robusta e modular em Ruby/Sinatra.

---

**Versão**: 1.0.0  
**Tecnologias**: Ruby, Sinatra, Prawn, caxlsx, Gruff, RSpec

