import React, { useState } from "react";

function ReportGenerator() {
  const [file, setFile] = useState(null);
  const [fileName, setFileName] = useState("");
  const [groupBy, setGroupBy] = useState("");
  const [sumField, setSumField] = useState("");

  const handleFileUpload = (e) => {
    const uploadedFile = e.target.files[0];
    setFile(uploadedFile);
    setFileName(uploadedFile ? uploadedFile.name : "");
  };

  const handleSubmit = (e) => {
    e.preventDefault();
    if (!file) {
      alert("Selecione um arquivo primeiro!");
      return;
    }
    console.log("Arquivo:", fileName);
    console.log("Group by:", groupBy);
    console.log("Sum field:", sumField);
    // Aqui você conecta com seu backend
  };

  return (
    <div className="card">
      <h2 className="card-title">Gerador de Relatórios</h2>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">

        {/* Upload de arquivo */}
        <div className="custom-file">
          <label htmlFor="fileInput" className="file-label">
            📂 Escolher arquivo
          </label>
          <input
            type="file"
            id="fileInput"
            onChange={handleFileUpload}
          />
          {fileName && <span className="file-name">{fileName}</span>}
        </div>

        {/* Campo Group By */}
        <div>
          <label className="block mb-1">Group by:</label>
          <input
            type="text"
            placeholder="categoria"
            className="custom-input"
            value={groupBy}
            onChange={(e) => setGroupBy(e.target.value)}
          />
        </div>

        {/* Campo Sum Field */}
        <div>
          <label className="block mb-1">Sum field:</label>
          <input
            type="text"
            placeholder="valor"
            className="custom-input"
            value={sumField}
            onChange={(e) => setSumField(e.target.value)}
          />
        </div>

        {/* Botão de envio */}
        <button type="submit" className="btn-modern">
          Gerar Relatório
        </button>
      </form>
    </div>
  );
}

export default ReportGenerator;
