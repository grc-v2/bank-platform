// MỘT nguồn sự thật về sáu service và đường info của chúng. Path của
// core-banking là /api/accounts/info vì gateway không có route
// /api/core-banking/** — xem spec.
export const API_BASE = import.meta.env.VITE_API_BASE ?? 'http://localhost:8080'

export const SERVICES = [
  { key: 'gateway-service', infoPath: '/api/gateway/info' },
  { key: 'auth-service', infoPath: '/api/auth/info' },
  { key: 'customer-service', infoPath: '/api/customers/info' },
  { key: 'product-service', infoPath: '/api/products/info' },
  { key: 'core-banking-service', infoPath: '/api/accounts/info' },
  { key: 'notification-service', infoPath: '/api/notifications/info' },
]
