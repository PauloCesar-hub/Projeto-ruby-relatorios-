import React, { useState } from "react";
import { Upload, Send } from "lucide-react"; // Ícones

export default function UploadSection() {
  const [fileName, setFileName] = useState("Nenhum arquivo selecionado");

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    setFileName(file ? file.name : "Nenhum arquivo selecionado");
  };

  return (
    <div className="container">
      {/* Escolher Arquivo */}
      <div style={{ marginBottom: "16px" }}>
        <label htmlFor="file-upload" className="file-label">
          <Upload size={18} style={{ marginRight: "8px" }} />
          Escolher Arquivo
        </label>
        <input id="file-upload" type="file" onChange={handleFileChange} />
        <p style={{ marginTop: "8px", fontSize: "14px" }}>{fileName}</p>
      </div>

      {/* Botão Enviar */}
      <div style={{ marginBottom: "16px" }}>
        <button className="btn">
          <Send size={18} style={{ marginRight: "8px" }} />
          Enviar
        </button>
      </div>

      {/* Selects Traduzidos */}
      <div style={{ display: "flex", gap: "16px", flexWrap: "wrap" }}>
        <div>
          <label htmlFor="group-by">Agrupar por:</label>
          <select id="group-by" defaultValue="categoria">
            <option value="categoria">Categoria</option>
            <option value="data">Data</option>
          </select>
        </div>

        <div>
          <label htmlFor="sum-field">Campo para Soma:</label>
          <select id="sum-field" defaultValue="valor">
            <option value="valor">Valor</option>
            <option value="quantidade">Quantidade</option>
          </select>
        </div>
      </div>
    </div>
  );
}
