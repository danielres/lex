import {mountLexicalEditor} from './mount'
import {mountRevisionPreview} from './revisionPreviewMount'
import {
  createWikiPageRepository,
  documentSnapshotsToParams,
} from './wiki/repository'

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
      const loadPageContentEvent = this.el.dataset.loadPageContentEvent
      const savePageEvent = this.el.dataset.savePageEvent
      const saveEvent = this.el.dataset.saveEvent
      const restoreCommitEvent = this.el.dataset.restoreCommitEvent
      const restorePreserveEvent = this.el.dataset.restorePreserveEvent
      const restoreRequestEvent = this.el.dataset.restoreRequestEvent
      const saveRequestEvent = this.el.dataset.saveRequestEvent

      const wikiPageRepository = createWikiPageRepository({
        saveEvent: savePageEvent,
        csrfToken,
        ensureEvent: ensurePageEvent,
        loadContentEvent: loadPageContentEvent,
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

      this.saveRequestRef = this.handleEvent(
        saveRequestEvent,
        async () => {
          try {
            if (!this.lexicalEditor) {
              throw new Error('Lexical editor is not mounted')
            }

            this.lexicalEditor.setEditable(false)
            const snapshots =
              await this.lexicalEditor.captureDocumentSnapshots()
            const documents = documentSnapshotsToParams(snapshots)

            this.pushEvent(saveEvent, {documents})
          } catch (error) {
            const reason =
              error instanceof Error ? error.message : String(error)
            this.pushEvent(saveEvent, {error: reason})
          }
        },
      )

      this.pageContentUpdatedRef = this.handleEvent(
        'page_content_updated',
        ({content_hash, lexical_state, page_id}) => {
          this.lexicalEditor?.setPageContent(page_id, {
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
              await this.lexicalEditor.captureDocumentSnapshots()
            const preserveReply = await requestPage(restorePreserveEvent, {
              documents: documentSnapshotsToParams(currentSnapshots),
            })

            if (!preserveReply.ok) return

            const snapshots =
              await this.lexicalEditor.restoreRevision(lexical_state)

            this.pushEvent(restoreCommitEvent, {
              documents: documentSnapshotsToParams(snapshots),
              revision_id,
            })
          } catch (_error) {
            this.pushEvent(restoreCommitEvent, {
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
      this.removeHandleEvent(this.saveRequestRef)
      this.removeHandleEvent(this.pageContentUpdatedRef)
      this.removeHandleEvent(this.restoreRequestRef)
      this.lexicalEditor?.unmount()
    },
  },

  LexicalRevisionPreview: {
    mounted() {
      const requestPage = (event, payload) =>
        new Promise((resolve) => this.pushEvent(event, payload, resolve))
      const wikiPageRepository = createWikiPageRepository({
        saveEvent: this.el.dataset.savePageEvent,
        csrfToken,
        ensureEvent: this.el.dataset.ensurePageEvent,
        loadContentEvent: this.el.dataset.loadPageContentEvent,
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

      this.pageContentUpdatedRef = this.handleEvent(
        'page_content_updated',
        ({content_hash, lexical_state, page_id}) => {
          this.revisionPreview?.setPageContent(page_id, {
            contentHash: content_hash,
            lexicalState: lexical_state,
          })
        },
      )
    },

    destroyed() {
      this.removeHandleEvent(this.pageContentUpdatedRef)
      this.revisionPreview?.unmount()
    },
  },
})
