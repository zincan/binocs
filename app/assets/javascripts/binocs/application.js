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

// Expose to window for manual control
window.Binocs = {
  startAutoRefresh,
  stopAutoRefresh
}
