import React, { useEffect, useState } from 'react'

export default function ThemeSwitcher(){
  const [theme, setTheme] = useState(()=> localStorage.getItem('theme') || 'dark')
  useEffect(()=>{
    document.documentElement.setAttribute('data-theme', theme)
    localStorage.setItem('theme', theme)
  }, [theme])
  return <button onClick={()=>setTheme(theme==='dark'?'light':'dark')}>{theme==='dark'?'☀️':'🌙'}</button>
}
