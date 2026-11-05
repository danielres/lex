import { mountRevisionPreview } from "../lexical_editor/revisionPreviewMount"
import { mountLexicalEditor } from "./mount"

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

export const createLexicalHooks = csrfToken => ({
  LexicalEditor: {
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
        csrfToken,
        documentId: this.el.dataset.documentId,
        initialEditable: this.el.dataset.editable === "true",
        initialPages: JSON.parse(this.el.dataset.pages || "[]"),
        spaceId: this.el.dataset.spaceId,
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
  },

  LexicalRevisionPreview: {
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
})
