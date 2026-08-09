import RouteTable from './RouteTable.jsx'

function formatUptime(seconds) {
  if (seconds == null) return '—'
  const h = Math.floor(seconds / 3600)
  const m = Math.floor((seconds % 3600) / 60)
  const s = seconds % 60
  return h > 0 ? `${h}h ${m}m` : m > 0 ? `${m}m ${s}s` : `${s}s`
}

function Row({ label, value }) {
  return (
    <div className="row">
      <span className="label">{label}</span>
      <span className="value">{value ?? '—'}</span>
    </div>
  )
}

export default function ServiceCard({ serviceKey, state }) {
  const info = state?.info
  const up = state?.up ?? false

  return (
    <section className={`card ${up ? 'up' : 'down'}`}>
      <div className="card-head">
        <h2>{info?.serviceName ?? serviceKey}</h2>
        <span className={`badge ${up ? 'badge-up' : 'badge-down'}`}>
          {up ? 'UP' : 'DOWN'}
        </span>
      </div>
      {info?.description && <p className="desc">{info.description}</p>}
      <Row label="Version" value={info?.version} />
      <Row label="Cổng" value={info?.port} />
      {info?.structureLevel && <Row label="Cấu trúc" value={info.structureLevel} />}
      {info?.dbSchema && <Row label="Schema" value={info.dbSchema} />}
      {info?.errorCodePrefix && <Row label="Mã lỗi" value={info.errorCodePrefix} />}
      <Row label="Spring Boot" value={info?.springBootVersion} />
      <Row label="Java" value={info?.javaVersion} />
      <Row label="Uptime" value={up ? formatUptime(info?.uptimeSeconds) : '—'} />
      {info?.dependencies?.length > 0 && (
        <div className="deps">
          {info.dependencies.map((dep) => (
            <span
              key={dep.name}
              className={`dep ${dep.status === 'UP' ? 'dep-up' : 'dep-down'}`}
            >
              {dep.name}
            </span>
          ))}
        </div>
      )}
      {info?.routes && <RouteTable routes={info.routes} />}
    </section>
  )
}
