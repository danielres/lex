import {mountLexicalEditor} from './mount'
import {mountRevisionPreview} from './revisionPreviewMount'
import {createWikiPageRepository, snapshotsToParams} from './wiki/repository'

const collaboratorFromElement = (element) => {
  const displayName = element.dataset.collaboratorDisplayName
  const hue = Number(element.dataset.collaboratorHue)

  if (!displayName || !Number.isInteger(hue) || hue < 0 || hue > 359) {
    throw new Error('Invalid collaborator data')
  }

  return {displayName, hue}
}

export const createLexicalHooks = (csrfToken) => ({
  LexicalEditor: {
    mounted() {
      const requestPage = (event, payload) =>
        new Promise((resolve) => this.pushEvent(event, payload, resolve))
      const ensurePageEvent = this.el.dataset.ensurePageEvent
      const resolvePageEvent = this.el.dataset.resolvePageEvent
      const loadPageSnapshotEvent = this.el.dataset.loadPageSnapshotEvent
      const checkpointPageEvent = this.el.dataset.checkpointPageEvent
      const checkpointEvent = this.el.dataset.checkpointEvent
      const restoreCheckpointEvent = this.el.dataset.restoreCheckpointEvent
      const restorePreserveEvent = this.el.dataset.restorePreserveEvent
      const restoreRequestEvent = this.el.dataset.restoreRequestEvent
      const snapshotRequestEvent = this.el.dataset.snapshotRequestEvent

      const wikiPageRepository = createWikiPageRepository({
        checkpointEvent: checkpointPageEvent,
        csrfToken,
        ensureEvent: ensurePageEvent,
        loadSnapshotEvent: loadPageSnapshotEvent,
        request: requestPage,
        resolveEvent: resolvePageEvent,
        spaceId: this.el.dataset.spaceId,
      })

      this.lexicalEditor = mountLexicalEditor(this.el, {
        collaborator: collaboratorFromElement(this.el),
        csrfToken,
        documentId: this.el.dataset.documentId,
        initialEditable: this.el.dataset.editable === 'true',
        initialPages: JSON.parse(this.el.dataset.pages || '[]'),
        spaceId: this.el.dataset.spaceId,
        wikiPageRepository,
      })

      this.snapshotRequestRef = this.handleEvent(
        snapshotRequestEvent,
        async () => {
          try {
            if (!this.lexicalEditor) {
              throw new Error('Lexical editor is not mounted')
            }

            this.lexicalEditor.setEditable(false)
            const snapshots =
              await this.lexicalEditor.getConfirmedDocumentSnapshots()
            const documents = snapshotsToParams(snapshots)

            this.pushEvent(checkpointEvent, {documents})
          } catch (error) {
            const reason =
              error instanceof Error ? error.message : String(error)
            this.pushEvent(checkpointEvent, {error: reason})
          }
        },
      )

      this.pageSnapshotUpdatedRef = this.handleEvent(
        'page_snapshot_updated',
        ({content_hash, lexical_state, page_id}) => {
          this.lexicalEditor?.setPageSnapshot(page_id, {
            contentHash: content_hash,
            lexicalState: lexical_state,
          })
        },
      )

      this.restoreRequestRef = this.handleEvent(
        restoreRequestEvent,
        async ({lexical_state, revision_id}) => {
          try {
            if (!this.lexicalEditor)
              throw new Error('Lexical editor is not mounted')

            const currentSnapshots =
              await this.lexicalEditor.getConfirmedDocumentSnapshots()
            const preserveReply = await requestPage(restorePreserveEvent, {
              documents: snapshotsToParams(currentSnapshots),
            })

            if (!preserveReply.ok) return

            const snapshots =
              await this.lexicalEditor.restoreRevision(lexical_state)

            this.pushEvent(restoreCheckpointEvent, {
              documents: snapshotsToParams(snapshots),
              revision_id,
            })
          } catch (_error) {
            this.pushEvent(restoreCheckpointEvent, {
              error: 'restore_failed',
              revision_id,
            })
          }
        },
      )
    },

    updated() {
      this.lexicalEditor?.setEditable(this.el.dataset.editable === 'true')
      this.lexicalEditor?.setPages(JSON.parse(this.el.dataset.pages || '[]'))
    },

    destroyed() {
      this.removeHandleEvent(this.snapshotRequestRef)
      this.removeHandleEvent(this.pageSnapshotUpdatedRef)
      this.removeHandleEvent(this.restoreRequestRef)
      this.lexicalEditor?.unmount()
    },
  },

  LexicalRevisionPreview: {
    mounted() {
      const requestPage = (event, payload) =>
        new Promise((resolve) => this.pushEvent(event, payload, resolve))
      const wikiPageRepository = createWikiPageRepository({
        checkpointEvent: this.el.dataset.checkpointPageEvent,
        csrfToken,
        ensureEvent: this.el.dataset.ensurePageEvent,
        loadSnapshotEvent: this.el.dataset.loadPageSnapshotEvent,
        request: requestPage,
        resolveEvent: this.el.dataset.resolvePageEvent,
        spaceId: this.el.dataset.spaceId,
      })

      this.revisionPreview = mountRevisionPreview(
        this.el,
        collaboratorFromElement(this.el),
        this.el.dataset.pageId,
        JSON.parse(this.el.dataset.lexicalState),
        JSON.parse(this.el.dataset.previousLexicalState),
        JSON.parse(this.el.dataset.pages || '[]'),
        wikiPageRepository,
      )

      this.pageSnapshotUpdatedRef = this.handleEvent(
        'page_snapshot_updated',
        ({content_hash, lexical_state, page_id}) => {
          this.revisionPreview?.setPageSnapshot(page_id, {
            contentHash: content_hash,
            lexicalState: lexical_state,
          })
        },
      )
    },

    destroyed() {
      this.removeHandleEvent(this.pageSnapshotUpdatedRef)
      this.revisionPreview?.unmount()
    },
  },
})
