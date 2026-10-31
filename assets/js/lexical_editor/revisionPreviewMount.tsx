import type {SerializedEditorState} from 'lexical';
import {createRoot} from 'react-dom/client';

import type {Collaborator} from './context/CollaborationContext';
import type {WikiPageReference} from './context/WikiPagesContext';
import RevisionPreview from './RevisionPreview';

export function mountRevisionPreview(
  element: HTMLElement,
  collaborator: Collaborator,
  lexicalState: SerializedEditorState,
  previousLexicalState: SerializedEditorState | null,
  pages: WikiPageReference[],
): () => void {
  const root = createRoot(element);
  root.render(
    <RevisionPreview
      collaborator={collaborator}
      lexicalState={lexicalState}
      pages={pages}
      previousLexicalState={previousLexicalState}
    />,
  );

  return () => root.unmount();
}
