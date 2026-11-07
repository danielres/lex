import type {SerializedEditorState} from 'lexical';

import type {Collaborator} from 'live_lexical/collaboration';
import {mountRevisionPreview as mountEditorRevisionPreview} from 'live_lexical/revision-preview';
import {wikiEditorIntegration} from './wiki/integration';
import {
  type WikiPageReference,
  type WikiPageRepository,
  type WikiPageContent,
  WikiPagesProvider,
} from './wiki/WikiPagesContext';

export interface MountedWikiRevisionPreview {
  setPageContent(pageId: string, content: WikiPageContent): void;
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
  let contentUpdates = new Map<string, WikiPageContent>();
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
        contentUpdates={contentUpdates}
      >
        {children}
      </WikiPagesProvider>
    ),
  );

  return {
    setPageContent(pageId, content) {
      contentUpdates = new Map(contentUpdates).set(pageId, content);
      preview.refresh();
    },
    unmount: preview.unmount,
  };
}
