const storageKey = "lex:local-settings"
const largeScreenQuery = "(min-width: 40rem)" // Tailwind sm breakpoint

const isSettingsObject = value =>
  value !== null && typeof value === "object" && !Array.isArray(value)

const isLargeScreen = () => matchMedia(largeScreenQuery).matches

const readStoredSettings = () => {
  try {
    const settings = JSON.parse(localStorage.getItem(storageKey) || "{}")

    return isSettingsObject(settings) ? settings : {}
  } catch (_error) {
    return {}
  }
}

const withClosedDrawer = settings => ({
  ...settings,
  drawer: {
    ...(isSettingsObject(settings.drawer) ? settings.drawer : {}),
    open: false,
  },
})

export const read = () => {
  const settings = readStoredSettings()

  return isLargeScreen() ? settings : withClosedDrawer(settings)
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

const withoutDrawerOpen = settings => {
  if (!isSettingsObject(settings.drawer)) return settings

  const persistentSettings = { ...settings }
  const drawer = { ...settings.drawer }

  delete drawer.open

  if (Object.keys(drawer).length === 0) {
    delete persistentSettings.drawer
  } else {
    persistentSettings.drawer = drawer
  }

  return persistentSettings
}

const update = settings => {
  if (!isSettingsObject(settings)) return

  const persistentSettings = isLargeScreen() ? settings : withoutDrawerOpen(settings)

  if (Object.keys(persistentSettings).length === 0) return

  try {
    localStorage.setItem(
      storageKey,
      JSON.stringify(mergeLocalSettings(readStoredSettings(), persistentSettings))
    )
  } catch (_error) {
    // localStorage may be unavailable; the server-side state still remains usable.
  }
}

export const initialize = () => {
  window.addEventListener("phx:local-settings-changed", ({ detail }) => {
    update(detail)
  })
}
