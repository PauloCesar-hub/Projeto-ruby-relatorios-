# 📊 Projeto Ruby Relatórios

## 📝 Visão Geral
O **Projeto Ruby Relatórios** é uma aplicação desenvolvida em **Ruby** para gerar e visualizar relatórios a partir de arquivos CSV.  
O sistema permite processar dados de forma simples e modular, com a lógica principal localizada no arquivo `lib/report_generator.rb`.

---

## 🚀 Funcionalidades
- 📂 Geração de relatórios a partir de arquivos CSV.  
- 🌐 Visualização dos relatórios via interface web local.  
- 🛠 Estrutura modular, permitindo customizações e melhorias futuras.  

---

## 🛠️ Tecnologias Utilizadas
- **Ruby** → Linguagem principal do projeto.  
- **Bundler** → Gerenciamento de dependências.  
- **Sinatra** *(ou framework similar)* → Interface web.  
- **CSV** → Manipulação e leitura de arquivos CSV.

---

## ⚙️ Como Executar o Projeto

### 1️⃣ Clone o repositório:
```bash
git clone https://github.com/PauloCesar-hub/Projeto-ruby-relatorios-.git
cd Projeto-ruby-relatorios-
bundle install
bundle exec ruby app.rb
http://localhost:8080


├── dados/              # Arquivos CSV de entrada
├── graficos/           # Saída de gráficos gerados
├── lib/
│   └── report_generator.rb   # Lógica central dos relatórios
├── relatorios/         # Relatórios processados
├── views/              # Templates HTML da interface web
├── .gitignore
├── Gemfile             # Lista de dependências
├── Gemfile.lock        # Versões travadas das gems
├── app.rb              # Script principal
├── web_app.rb          # Extensão da interface web
├── generate_reports.rb # Script auxiliar para geração de relatórios
└── gerar_csv.rb        # Script auxiliar para criação de CSVs

📌 Sugestões de Melhorias Futuras

🔍 Documentação detalhada sobre os scripts e módulos.

📑 Exportação de relatórios para PDF, Excel ou gráficos interativos.

✅ Testes automatizados (RSpec ou Minitest).

🔗 API REST para integração com outros sistemas.

⚡ Interface web mais moderna com gráficos dinâmicos.


📧 Contato

📌 Autor: Paulo Cesar
🔗 GitHub: PauloCesar-hub
