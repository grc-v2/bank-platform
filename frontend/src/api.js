import { API_BASE } from './services.js'

// Timeout 3s: một service treo không được phép giữ cả vòng poll. Lỗi mạng,
// timeout, hay HTTP != 2xx đều quy về {up: false} — thẻ hiển thị DOWN,
// không throw lên UI.
export async function fetchInfo(infoPath) {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 3000)
  try {
    const res = await fetch(`${API_BASE}${infoPath}`, { signal: controller.signal })
    if (!res.ok) return { up: false }
    const body = await res.json()
    return { up: true, info: body.data }
  } catch {
    return { up: false }
  } finally {
    clearTimeout(timer)
  }
}
