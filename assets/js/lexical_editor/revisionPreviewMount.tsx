import type {SerializedEditorState} from 'lexical';
import {createRoot} from 'react-dom/client';

import type {WikiPageReference} from './context/WikiPagesContext';
import RevisionPreview from './RevisionPreview';

export function mountRevisionPreview(
  element: HTMLElement,
  lexicalState: SerializedEditorState,
  previousLexicalState: SerializedEditorState | null,
  pages: WikiPageReference[],
): () => void {
  const root = createRoot(element);
  root.render(
    <RevisionPreview
      lexicalState={lexicalState}
      pages={pages}
      previousLexicalState={previousLexicalState}
    />,
  );

  return () => root.unmount();
}
