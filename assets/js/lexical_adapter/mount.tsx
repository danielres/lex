import type {Collaborator} from 'live_lexical/collaboration';
import type {
  WikiPageReference,
  WikiPageRepository,
  WikiPageSnapshot,
} from './wiki/WikiPagesContext';
import {mountEditor, type MountedEditor} from 'live_lexical/mount';
import {createPhoenixCollaboration} from './phoenixCollaboration';
import {wikiEditorIntegration} from './wiki/integration';
import {WikiPagesProvider} from './wiki/WikiPagesContext';

export interface MountedLexicalEditor extends Omit<MountedEditor, 'refresh'> {
  setPageSnapshot(pageId: string, snapshot: WikiPageSnapshot): void;
  setPages(pages: WikiPageReference[]): void;
}

export function mountLexicalEditor(
  element: HTMLElement,
  {
    collaborator,
    csrfToken,
    documentId,
    initialEditable,
    initialPages,
    spaceId,
    wikiPageRepository,
  }: {
    collaborator: Collaborator;
    csrfToken: string;
    documentId: string;
    initialEditable: boolean;
    initialPages: WikiPageReference[];
    spaceId: string;
    wikiPageRepository: WikiPageRepository;
  },
): MountedLexicalEditor {
  const collaboration = createPhoenixCollaboration(
    documentId,
    spaceId,
    csrfToken,
  );

  let pages = initialPages;
  let snapshotUpdates = new Map<string, WikiPageSnapshot>();
  const editor = mountEditor(element, {
    collaboration,
    collaborator,
    initialEditable,
    integration: wikiEditorIntegration,
    renderEnvironment: (children) => (
      <WikiPagesProvider
        collaborator={collaborator}
        currentPageId={documentId}
        initialPages={pages}
        integration={wikiEditorIntegration}
        repository={wikiPageRepository}
        snapshotUpdates={snapshotUpdates}
      >
        {children}
      </WikiPagesProvider>
    ),
  });
  const {refresh, ...mountedEditor} = editor;

  return {
    ...mountedEditor,
    setPageSnapshot(pageId, snapshot) {
      snapshotUpdates = new Map(snapshotUpdates).set(pageId, snapshot);
      refresh();
    },
    setPages(nextPages) {
      pages = nextPages;
      refresh();
    },
  };
}
