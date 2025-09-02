import axios from 'axios'

const api = axios.create({
  baseURL: import.meta.env.VITE_API_URL || '',
  withCredentials: false,
})

export async function uploadCsv(file) {
  const fd = new FormData()
  fd.append('file', file)
  const { data } = await api.post('/api/upload', fd, {
    headers: { 'Content-Type': 'multipart/form-data' }
  })
  return data
}

export async function fetchSeries(fileName, group, sum) {
  const { data } = await api.get('/api/series', {
    params: { file: fileName, group, sum }
  })
  return data
}

export async function generateReport(fileName, format='csv') {
  const fd = new FormData()
  fd.append('file', fileName) // envia apenas o nome do CSV já salvo
  fd.append('format', format)
  const { data } = await api.post('/api/report', fd)
  return data
}

export default api
