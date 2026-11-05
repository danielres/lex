import type {SerializedEditorState} from 'lexical';

import type {Collaborator} from '../lexical_editor/context/CollaborationContext';
import {mountRevisionPreview as mountEditorRevisionPreview} from '../lexical_editor/revisionPreviewMount';
import {wikiEditorIntegration} from './wiki/integration';
import {
  type WikiPageReference,
  type WikiPageRepository,
  WikiPagesProvider,
} from './wiki/WikiPagesContext';

const readOnlyWikiPageRepository: WikiPageRepository = {
  ensure: async () => {
    throw new Error('Read-only editors cannot create pages');
  },
  resolve: async () => null,
};

export function mountRevisionPreview(
  element: HTMLElement,
  collaborator: Collaborator,
  lexicalState: SerializedEditorState,
  previousLexicalState: SerializedEditorState | null,
  pages: WikiPageReference[],
): () => void {
  return mountEditorRevisionPreview(
    element,
    collaborator,
    lexicalState,
    previousLexicalState,
    wikiEditorIntegration,
    children => (
      <WikiPagesProvider
        initialPages={pages}
        repository={readOnlyWikiPageRepository}
      >
        {children}
      </WikiPagesProvider>
    ),
  );
}
