import type {SerializedEditorState} from 'lexical';

import type {Collaborator} from 'live_lexical/collaboration';
import {mountRevisionPreview as mountEditorRevisionPreview} from 'live_lexical/revision-preview';
import {wikiEditorIntegration} from './wiki/integration';
import {
  type WikiPageReference,
  type WikiPageRepository,
  type WikiPageSnapshot,
  WikiPagesProvider,
} from './wiki/WikiPagesContext';

export interface MountedWikiRevisionPreview {
  setPageSnapshot(pageId: string, snapshot: WikiPageSnapshot): void;
  unmount(): void;
}

export function mountRevisionPreview(
  element: HTMLElement,
  collaborator: Collaborator,
  currentPageId: string,
  lexicalState: SerializedEditorState,
  previousLexicalState: SerializedEditorState | null,
  pages: WikiPageReference[],
  repository: WikiPageRepository,
): MountedWikiRevisionPreview {
  let snapshotUpdates = new Map<string, WikiPageSnapshot>();
  const preview = mountEditorRevisionPreview(
    element,
    collaborator,
    lexicalState,
    previousLexicalState,
    wikiEditorIntegration,
    (children) => (
      <WikiPagesProvider
        collaborator={collaborator}
        currentPageId={currentPageId}
        initialPages={pages}
        integration={wikiEditorIntegration}
        repository={repository}
        snapshotUpdates={snapshotUpdates}
      >
        {children}
      </WikiPagesProvider>
    ),
  );

  return {
    setPageSnapshot(pageId, snapshot) {
      snapshotUpdates = new Map(snapshotUpdates).set(pageId, snapshot);
      preview.refresh();
    },
    unmount: preview.unmount,
  };
}
