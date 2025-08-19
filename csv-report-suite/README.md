
# Suite de Relatórios (CSV • PDF • XLSX) — Ruby + Sinatra

Gera relatórios a partir de **arquivo** (.csv/.json) ou **URL de API** (JSON). Exporta **CSV, PDF e XLSX**, com **gráfico de pizza** e **totalizador** (quando houver valores).

## Rodando
```bash
bundle install
bundle exec rake server
# abra http://localhost:4567
```

## Uso
- Preencha **arquivo** OU **URL**.
- Escolha **tipo** (Despesas/Notas), campos e período (opcional).
- Clique no formato: **CSV**, **PDF** ou **XLSX**.

## Dependências importantes
- `prawn` + `prawn-table` — PDF
- `gruff` — gráfico (pie)
- `axlsx` — Excel
```

