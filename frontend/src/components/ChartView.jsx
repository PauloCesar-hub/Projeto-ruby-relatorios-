import React from 'react'
import { BarChart, Bar, XAxis, YAxis, Tooltip, CartesianGrid, ResponsiveContainer, Legend } from 'recharts'

export default function ChartView({ labels = [], values = [] }) {
  if (!labels || labels.length === 0) return null
  const data = labels.map((l, i) => ({ name: String(l), value: values?.[i] ?? 0 }))
  return (
    <section className="panel" style={{marginTop:12}}>
      <h3 style={{marginTop:0}}>Gráfico de Barras</h3>
      <div style={{width:'100%', height:320}}>
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} margin={{ top: 20, right: 20, left: 0, bottom: 5 }}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="name" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Bar dataKey="value" barSize={40} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </section>
  )
}
