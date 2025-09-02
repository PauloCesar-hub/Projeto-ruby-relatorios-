import React, { useState } from 'react'

export default function UploadForm({ onUpload, loading }) {
  const [file, setFile] = useState(null)
  function submit(e){
    e.preventDefault()
    if (file) onUpload(file)
  }
  return (
    <form onSubmit={submit} className="panel">
      <h3 style={{marginTop:0}}>Enviar CSV</h3>
      <div className="row gap">
        <input type="file" accept=".csv" onChange={(e)=>setFile(e.target.files?.[0] ?? null)} />
        <button disabled={!file || loading} type="submit">Enviar</button>
      </div>
    </form>
  )
}
