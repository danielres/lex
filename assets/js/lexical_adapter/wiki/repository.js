import {createPhoenixCollaboration} from '../phoenixCollaboration'

const documentSnapshotsToParams = (snapshots) =>
  snapshots.map((snapshot) => ({
    document_key: snapshot.documentKey,
    lexical_state: snapshot.lexicalState,
    search_text: snapshot.searchText,
  }))

export const createWikiPageRepository = ({
  csrfToken,
  ensureEvent,
  loadContentEvent,
  request,
  resolveEvent,
  saveEvent,
  spaceId,
}) => ({
  async save(id, snapshots) {
    const reply = await request(saveEvent, {
      documents: documentSnapshotsToParams(snapshots),
      page_id: id,
    })
    return reply.ok === true
  },

  createCollaboration(id) {
    return createPhoenixCollaboration(id, spaceId, csrfToken)
  },

  async ensure(title) {
    const reply = await request(ensureEvent, {title})
    if (!reply.ok) throw new Error(reply.error)
    return reply.page
  },

  async loadContent(id) {
    const reply = await request(loadContentEvent, {id})
    if (!reply.ok) return null

    return reply.content
      ? {
          contentHash: reply.content.content_hash,
          lexicalState: reply.content.lexical_state,
        }
      : {contentHash: null, lexicalState: null}
  },

  async resolve(id) {
    const reply = await request(resolveEvent, {id})
    return reply.ok ? reply.page : null
  },
})

export {documentSnapshotsToParams}
