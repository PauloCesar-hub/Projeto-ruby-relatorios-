import React, { useMemo, useState } from 'react'
import './styles.css'
import UploadForm from './components/UploadForm'
import DataTable from './components/DataTable'
import ChartView from './components/ChartView'
import ThemeSwitcher from './components/ThemeSwitcher'
import { uploadCsv, fetchSeries, generateReport } from './api'

export default function App() {
  const [fileName, setFileName] = useState('')
  const [fields, setFields] = useState([])
  const [preview, setPreview] = useState([])
  const [series, setSeries] = useState({ labels: [], values: [] })
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')
  const [groupField, setGroupField] = useState('')
  const [sumField, setSumField] = useState('')

  async function handleUpload(file) {
    setError('')
    setBusy(true)
    try {
      const res = await uploadCsv(file)
      setFileName(res.file)
      setFields(res.fields)
      setPreview(res.preview || [])
      if (res.fields?.length >= 2) {
        setGroupField(res.fields[0])
        setSumField(res.fields[1])
      }
    } catch (e) {
      setError(e?.response?.data?.message || e.message)
    } finally { setBusy(false) }
  }

  async function handleSeries() {
    if (!fileName || !groupField || !sumField) return
    setBusy(true)
    setError('')
    try {
      const res = await fetchSeries(fileName, groupField, sumField)
      setSeries(res)
    } catch (e) {
      setError(e?.response?.data?.message || e.message)
    } finally { setBusy(false) }
  }

  async function handleGenerate(format) {
    if (!fileName) return
    setBusy(true)
    setError('')
    try {
      const res = await generateReport(fileName, format)
      if (res.download_url) {
        const link = document.createElement('a')
        link.href = `${import.meta.env.VITE_API_URL || ''}${res.download_url}`
        link.download = res.download_url.split('/').pop()
        document.body.appendChild(link)
        link.click()
        link.remove()
      } else {
        alert('Erro: arquivo não gerado')
      }
    } catch (e) {
      setError(e?.response?.data?.message || e.message)
    } finally { setBusy(false) }
  }

  const canSeries = useMemo(() => !!(fileName && groupField && sumField), [fileName, groupField, sumField])

  return (
    <div className="container">
      <header className="topbar">
        <h1>Suite de Relatórios CSV</h1>
        <ThemeSwitcher />
      </header>

      <UploadForm onUpload={handleUpload} loading={busy} />

      {error && <div className="alert">{error}</div>}

      {fields.length > 0 && (
        <section className="panel">
          <div className="row gap">
            <div>
              <label>Campo de Agrupamento</label>
              <select value={groupField} onChange={e=>setGroupField(e.target.value)}>
                <option value="">Selecione</option>
                {fields.map(f => <option key={f} value={f}>{f}</option>)}
              </select>
            </div>
            <div>
              <label>Campo de Soma</label>
              <select value={sumField} onChange={e=>setSumField(e.target.value)}>
                <option value="">Selecione</option>
                {fields.map(f => <option key={f} value={f}>{f}</option>)}
              </select>
            </div>
            <button disabled={!canSeries || busy} onClick={handleSeries}>Gerar Série</button>
            <div className="spacer" />
            <button onClick={()=>handleGenerate('csv')} disabled={busy}>Exportar CSV</button>
            <button onClick={()=>handleGenerate('xlsx')} disabled={busy}>Exportar XLSX</button>
            <button onClick={()=>handleGenerate('pdf')} disabled={busy}>Exportar PDF</button>
          </div>
        </section>
      )}

      {preview.length > 0 && <DataTable rows={preview} />}
      {(series.labels?.length ?? 0) > 0 && <ChartView labels={series.labels} values={series.values} />}
    </div>
  )
}
