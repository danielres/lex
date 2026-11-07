import type {Collaborator} from 'live_lexical/collaboration';
import type {
  WikiPageReference,
  WikiPageRepository,
  WikiPageContent,
} from './wiki/WikiPagesContext';
import {mountEditor, type MountedEditor} from 'live_lexical/mount';
import {createPhoenixCollaboration} from './phoenixCollaboration';
import {wikiEditorIntegration} from './wiki/integration';
import {WikiPagesProvider} from './wiki/WikiPagesContext';

export interface MountedLexicalEditor extends Omit<MountedEditor, 'refresh'> {
  setPageContent(pageId: string, content: WikiPageContent): void;
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
  let contentUpdates = new Map<string, WikiPageContent>();
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
        contentUpdates={contentUpdates}
      >
        {children}
      </WikiPagesProvider>
    ),
  });
  const {refresh, ...mountedEditor} = editor;

  return {
    ...mountedEditor,
    setPageContent(pageId, content) {
      contentUpdates = new Map(contentUpdates).set(pageId, content);
      refresh();
    },
    setPages(nextPages) {
      pages = nextPages;
      refresh();
    },
  };
}
