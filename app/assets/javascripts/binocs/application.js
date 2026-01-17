// Binocs Application JavaScript
import "@hotwired/turbo-rails"

// Auto-scroll to top when new request is prepended
document.addEventListener("turbo:before-stream-render", (event) => {
  const stream = event.target
  if (stream.action === "prepend" && stream.target === "requests-list") {
    // Highlight the new element briefly
    const originalRender = event.detail.render
    event.detail.render = (streamElement) => {
      originalRender(streamElement)
      const newElement = document.querySelector("#requests-list > :first-child")
      if (newElement) {
        newElement.classList.add("turbo-stream-prepend")
      }
    }
  }
})

// Auto-refresh toggle functionality
let autoRefreshInterval = null

function startAutoRefresh() {
  if (autoRefreshInterval) return
  autoRefreshInterval = setInterval(() => {
    const frame = document.querySelector("#requests-list")
    if (frame) {
      Turbo.visit(window.location.href, { frame: "requests-list" })
    }
  }, 5000)
}

function stopAutoRefresh() {
  if (autoRefreshInterval) {
    clearInterval(autoRefreshInterval)
    autoRefreshInterval = null
  }
}

// WebSocket connection monitoring for authentication
let connectionAttempts = 0
let wasEverConnected = false

function setupConnectionMonitoring() {
  if (typeof Turbo === 'undefined' || !Turbo.cable) {
    // Turbo cable not available yet, retry
    setTimeout(setupConnectionMonitoring, 100)
    return
  }

  const consumer = Turbo.cable

  // Monitor connection events
  const originalOpen = consumer.connection.events.open
  const originalClose = consumer.connection.events.close

  consumer.connection.events.open = function() {
    wasEverConnected = true
    connectionAttempts = 0
    hideAuthBanner()
    if (originalOpen) originalOpen.call(this)
  }

  consumer.connection.events.close = function(event) {
    connectionAttempts++
    // If we've never connected and have tried a few times, likely auth issue
    if (!wasEverConnected && connectionAttempts >= 2) {
      showAuthBanner()
    }
    if (originalClose) originalClose.call(this, event)
  }

  // Also check initial state after a delay
  setTimeout(() => {
    if (!wasEverConnected && !consumer.connection.isOpen()) {
      showAuthBanner()
    }
  }, 2000)
}

function showAuthBanner() {
  const banner = document.getElementById('binocs-auth-banner')
  if (banner) {
    banner.classList.remove('hidden')
  }
}

function hideAuthBanner() {
  const banner = document.getElementById('binocs-auth-banner')
  if (banner) {
    banner.classList.add('hidden')
  }
}

// Initialize connection monitoring when DOM is ready
document.addEventListener('DOMContentLoaded', setupConnectionMonitoring)
document.addEventListener('turbo:load', setupConnectionMonitoring)

// Expose to window for manual control
window.Binocs = {
  startAutoRefresh,
  stopAutoRefresh,
  showAuthBanner,
  hideAuthBanner
}
