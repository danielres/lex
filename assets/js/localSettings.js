const storageKey = "lex:local-settings"

const isSettingsObject = value =>
  value !== null && typeof value === "object" && !Array.isArray(value)

export const read = () => {
  try {
    const settings = JSON.parse(localStorage.getItem(storageKey) || "{}")

    return isSettingsObject(settings) ? settings : {}
  } catch (_error) {
    return {}
  }
}

const mergeLocalSettings = (settings, update) =>
  Object.entries(update).reduce(
    (merged, [key, value]) => ({
      ...merged,
      [key]: isSettingsObject(value)
        ? mergeLocalSettings(isSettingsObject(merged[key]) ? merged[key] : {}, value)
        : value,
    }),
    settings
  )

const update = settings => {
  if (!isSettingsObject(settings)) return

  try {
    localStorage.setItem(storageKey, JSON.stringify(mergeLocalSettings(read(), settings)))
  } catch (_error) {
    // localStorage may be unavailable; the server-side state still remains usable.
  }
}

export const initialize = () => {
  window.addEventListener("phx:local-settings-changed", ({ detail }) => {
    update(detail)
  })
}
