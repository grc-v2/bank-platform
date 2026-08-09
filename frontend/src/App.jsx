import { useEffect, useState } from 'react'
import { SERVICES } from './services.js'
import { fetchInfo } from './api.js'
import ServiceCard from './components/ServiceCard.jsx'

const POLL_MS = 10_000

export default function App() {
  // state[key] = { up, info } — info giữ lại lần cuối thấy được để thẻ DOWN
  // vẫn hiển thị dữ liệu tĩnh thay vì trống trơn.
  const [state, setState] = useState({})
  const [lastPoll, setLastPoll] = useState(null)

  useEffect(() => {
    let cancelled = false

    async function poll() {
      // allSettled: một service chết không kéo các thẻ khác chết theo.
      const results = await Promise.allSettled(
        SERVICES.map((svc) => fetchInfo(svc.infoPath)),
      )
      if (cancelled) return
      setState((prev) => {
        const next = { ...prev }
        SERVICES.forEach((svc, i) => {
          const r = results[i]
          const value = r.status === 'fulfilled' ? r.value : { up: false }
          next[svc.key] = {
            up: value.up,
            info: value.up ? value.info : prev[svc.key]?.info,
          }
        })
        return next
      })
      setLastPoll(new Date())
    }

    poll()
    const timer = setInterval(poll, POLL_MS)
    return () => {
      cancelled = true
      clearInterval(timer)
    }
  }, [])

  return (
    <main className="app">
      <header>
        <h1>bank-platform</h1>
        <p className="subtitle">
          Dashboard service — tự refresh mỗi {POLL_MS / 1000}s
          {lastPoll && ` · lần cuối: ${lastPoll.toLocaleTimeString('vi-VN')}`}
        </p>
      </header>
      <div className="grid">
        {SERVICES.map((svc) => (
          <ServiceCard key={svc.key} serviceKey={svc.key} state={state[svc.key]} />
        ))}
      </div>
    </main>
  )
}
