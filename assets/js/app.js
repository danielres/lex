// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/lex"
import topbar from "topbar"
import Toast from "../../deps/toast/assets/js/toast.js"

import { AutoAnimate } from "./hooks/AutoAnimate"
import { CapitalizeFirstLetter } from "./hooks/CapitalizeFirstLetter"
import { mountLexicalEditor } from "./lexical_editor/mount"
import { mountRevisionPreview } from "./lexical_editor/revisionPreviewMount"

const snapshotsToParams = snapshots =>
  snapshots.map(snapshot => ({
    document_key: snapshot.documentKey,
    lexical_state: snapshot.lexicalState,
    search_text: snapshot.searchText
  }))

const collaboratorFromElement = element => {
  const displayName = element.dataset.collaboratorDisplayName
  const hue = Number(element.dataset.collaboratorHue)

  if (!displayName || !Number.isInteger(hue) || hue < 0 || hue > 359) {
    throw new Error("Invalid collaborator data")
  }

  return { displayName, hue }
}

const LexicalEditor = {
  mounted() {
    const requestPage = (event, payload) =>
      new Promise(resolve => this.pushEvent(event, payload, resolve))
    const ensurePageEvent = this.el.dataset.ensurePageEvent
    const resolvePageEvent = this.el.dataset.resolvePageEvent
    const checkpointEvent = this.el.dataset.checkpointEvent
    const restoreCheckpointEvent = this.el.dataset.restoreCheckpointEvent
    const restorePreserveEvent = this.el.dataset.restorePreserveEvent
    const restoreRequestEvent = this.el.dataset.restoreRequestEvent
    const snapshotRequestEvent = this.el.dataset.snapshotRequestEvent

    const wikiPageRepository = {
      async ensure(title) {
        const reply = await requestPage(ensurePageEvent, { title })
        if (!reply.ok) throw new Error(reply.error)
        return reply.page
      },
      async resolve(id) {
        const reply = await requestPage(resolvePageEvent, { id })
        return reply.ok ? reply.page : null
      },
    }

    this.lexicalEditor = mountLexicalEditor(this.el, {
      collaborator: collaboratorFromElement(this.el),
      documentId: this.el.dataset.documentId,
      initialEditable: this.el.dataset.editable === "true",
      initialPages: JSON.parse(this.el.dataset.pages || "[]"),
      wikiPageRepository,
    })

    this.snapshotRequestRef = this.handleEvent(snapshotRequestEvent, () => {
      try {
        this.lexicalEditor?.setEditable(false)
        const documents = snapshotsToParams(this.lexicalEditor?.getDocumentSnapshots() || [])

        this.pushEvent(checkpointEvent, { documents })
      } catch (_error) {
        this.pushEvent(checkpointEvent, { error: "snapshot_failed" })
      }
    })

    this.restoreRequestRef = this.handleEvent(
      restoreRequestEvent,
      async ({ lexical_state, revision_id }) => {
        try {
          if (!this.lexicalEditor) throw new Error("Lexical editor is not mounted")

          const currentSnapshots = await this.lexicalEditor.getConfirmedDocumentSnapshots()
          const preserveReply = await requestPage(restorePreserveEvent, {
            documents: snapshotsToParams(currentSnapshots)
          })

          if (!preserveReply.ok) return

          const snapshots = await this.lexicalEditor.restoreRevision(lexical_state)

          this.pushEvent(restoreCheckpointEvent, {
            documents: snapshotsToParams(snapshots),
            revision_id
          })
        } catch (_error) {
          this.pushEvent(restoreCheckpointEvent, {
            error: "restore_failed",
            revision_id
          })
        }
      }
    )
  },

  updated() {
    this.lexicalEditor?.setEditable(this.el.dataset.editable === "true")
    this.lexicalEditor?.setPages(JSON.parse(this.el.dataset.pages || "[]"))
  },

  destroyed() {
    this.removeHandleEvent(this.snapshotRequestRef)
    this.removeHandleEvent(this.restoreRequestRef)
    this.lexicalEditor?.unmount()
  }
}

const LexicalRevisionPreview = {
  mounted() {
    this.unmountPreview = mountRevisionPreview(
      this.el,
      collaboratorFromElement(this.el),
      JSON.parse(this.el.dataset.lexicalState),
      JSON.parse(this.el.dataset.previousLexicalState),
      JSON.parse(this.el.dataset.pages || "[]")
    )
  },

  destroyed() {
    this.unmountPreview?.()
  }
}

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const timeZone = Intl.DateTimeFormat().resolvedOptions().timeZone;

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken, tz: timeZone },
  hooks: {
    ...colocatedHooks,
    Toast,
    AutoAnimate,
    CapitalizeFirstLetter,
    LexicalEditor,
    LexicalRevisionPreview,
  },
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", _e => keyDown = null)
    window.addEventListener("click", e => {
      if (keyDown === "c") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if (keyDown === "d") {
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
