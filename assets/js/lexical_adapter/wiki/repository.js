import {createPhoenixCollaboration} from '../phoenixCollaboration'

const snapshotsToParams = (snapshots) =>
  snapshots.map((snapshot) => ({
    document_key: snapshot.documentKey,
    lexical_state: snapshot.lexicalState,
    search_text: snapshot.searchText,
  }))

export const createWikiPageRepository = ({
  checkpointEvent,
  csrfToken,
  ensureEvent,
  loadSnapshotEvent,
  request,
  resolveEvent,
  spaceId,
}) => ({
  async checkpoint(id, snapshots) {
    const reply = await request(checkpointEvent, {
      documents: snapshotsToParams(snapshots),
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

  async loadSnapshot(id) {
    const reply = await request(loadSnapshotEvent, {id})
    if (!reply.ok) return null

    return reply.snapshot
      ? {
          contentHash: reply.snapshot.content_hash,
          lexicalState: reply.snapshot.lexical_state,
        }
      : {contentHash: null, lexicalState: null}
  },

  async resolve(id) {
    const reply = await request(resolveEvent, {id})
    return reply.ok ? reply.page : null
  },
})

export {snapshotsToParams}
