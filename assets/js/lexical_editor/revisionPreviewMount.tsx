import type {SerializedEditorState} from 'lexical';
import {createRoot} from 'react-dom/client';
import type {ReactNode} from 'react';

import type {Collaborator} from './collaboration';
import type {EditorIntegration} from './integration';
import RevisionPreview from './RevisionPreview';

export function mountRevisionPreview(
  element: HTMLElement,
  collaborator: Collaborator,
  lexicalState: SerializedEditorState,
  previousLexicalState: SerializedEditorState | null,
  integration: EditorIntegration,
  renderEnvironment: (children: ReactNode) => ReactNode,
): () => void {
  const root = createRoot(element);
  const preview = (
    <RevisionPreview
      collaborator={collaborator}
      integration={integration}
      lexicalState={lexicalState}
      previousLexicalState={previousLexicalState}
    />
  );
  root.render(renderEnvironment(preview));

  return () => root.unmount();
}
