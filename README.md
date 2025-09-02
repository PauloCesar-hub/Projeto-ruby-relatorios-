# 📊 Projeto Ruby Relatórios — Melhorias V6 com Recharts

![GitHub repo size](https://img.shields.io/github/repo-size/PauloCesar-hub/Projeto-ruby-relatorios-?color=blue&style=for-the-badge)
![GitHub last commit](https://img.shields.io/github/last-commit/PauloCesar-hub/Projeto-ruby-relatorios-?style=for-the-badge)
![GitHub issues](https://img.shields.io/github/issues/PauloCesar-hub/Projeto-ruby-relatorios-?color=yellow&style=for-the-badge)
![GitHub license](https://img.shields.io/github/license/PauloCesar-hub/Projeto-ruby-relatorios-?style=for-the-badge)

## 📝 Descrição

O **Projeto Ruby Relatórios — Melhorias V6** é uma aplicação completa que gera relatórios dinâmicos a partir de dados CSV, exibindo gráficos interativos via **Recharts** no frontend.  
Além disso, o sistema exporta relatórios em diferentes formatos, como **CSV**, **PDF** e **XLSX**.

---

## 🚀 Funcionalidades

- 📥 Upload de arquivos CSV para processamento
- 📊 Visualização de relatórios interativos com **Recharts**
- 📑 Exportação dos relatórios para:
  - CSV
  - PDF
  - XLSX
- 🖥️ Backend robusto em **Ruby**
- ⚡ Frontend moderno com **Vite** + **Recharts**
- 🔄 Integração entre backend e frontend para atualização em tempo real

---

## 🛠️ Tecnologias Utilizadas

### **Backend**
- [Ruby](https://www.ruby-lang.org/)
- [Rack](https://rack.github.io/) — estrutura para servidores Ruby
- [CSV](https://ruby-doc.org/stdlib/libdoc/csv/rdoc/CSV.html) — leitura e manipulação de dados
- Geração de relatórios:
  - **Prawn** → PDF
  - **CSV Exporter** → CSV
  - **XLSX Exporter** → XLSX

### **Frontend**
- [Vite](https://vitejs.dev/)
- [Recharts](https://recharts.org/) → gráficos dinâmicos
- [JavaScript](https://developer.mozilla.org/docs/Web/JavaScript)
- [HTML5](https://developer.mozilla.org/docs/Web/Guide/HTML/HTML5)

---

## 📦 Pré-requisitos

Antes de começar, verifique se possui as seguintes ferramentas instaladas:

- **Ruby** >= 3.0
- **Bundler** >= 2.0
- **Node.js** >= 18
- **npm** ou **yarn**

Verifique as versões com:

```bash
ruby -v
bundler -v
node -v
npm -v

🔧 Instalação

Clone o repositório:

git clone https://github.com/PauloCesar-hub/Projeto-ruby-relatorios-.git
cd Projeto-ruby-relatorios-

Backend

Entre na pasta do backend, instale as dependências e inicie o servidor:

cd backend
bundle install
rackup


O servidor será iniciado por padrão em:
http://localhost:9292

Frontend

Em outro terminal, vá para a pasta do frontend e instale as dependências:

cd frontend
npm install
npm run dev


O frontend será iniciado em:
http://localhost:5173

▶️ Como Usar

Acesse a aplicação no navegador via http://localhost:5173

Faça upload do arquivo CSV com os dados.

Visualize os gráficos gerados dinamicamente.

Exporte os relatórios nos formatos desejados.

📂 Estrutura de Pastas
Projeto-ruby-relatorios-
├── backend/                # API e processamento de relatórios em Ruby
│   ├── app.rb              # Ponto principal da aplicação
│   ├── lib/csv_report_suite/ # Manipulação e exportação de relatórios
│   └── public/uploads/     # Armazena arquivos CSV enviados
├── frontend/               # Interface gráfica e visualização de dados
│   ├── index.html
│   ├── src/                # Código fonte do frontend
│   ├── package.json
│   └── vite.config.mjs
└── README.md

📊 Exemplo de Relatório Gerado

Entrada: Arquivo CSV com dados de vendas.

Saída:

Gráficos interativos no navegador.

Relatórios exportáveis nos formatos CSV, PDF e XLSX.

🤝 Contribuindo

Contribuições são sempre bem-vindas!

Faça um fork do projeto.

Crie uma branch para sua feature:

git checkout -b minha-feature


Commit suas mudanças:

git commit -m "Minha nova feature"


Envie para a branch:

git push origin minha-feature


Abra um Pull Request.

🧾 Licença

Este projeto está sob a licença MIT.
Sinta-se livre para usar, modificar e distribuir.

📌 Autor

Paulo Cesar
🔗 GitHub


---

Quer que eu também adicione **badges dinâmicos** para **versão do Ruby**, **Node.js** e **status do build** para deixar o README ainda mais profissional?  
Isso deixa o projeto mais atrativo no GitHub. Quer que eu faça?
