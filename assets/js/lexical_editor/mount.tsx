/**
 * The editor is derived from Meta's Lexical playground, licensed under MIT.
 */

import './index.css';

import {createRoot} from 'react-dom/client';

import PlaygroundApp from './App';
import {createPhoenixCollaboration} from './collaboration';
import './setupEnv';

export interface MountedLexicalEditor {
  unmount(): void;
}

export function mountLexicalEditor(
  element: HTMLElement,
  documentId: string,
): MountedLexicalEditor {
  const collaboration = createPhoenixCollaboration(documentId);
  const root = createRoot(element);
  root.render(
    <PlaygroundApp providerFactory={collaboration.providerFactory} />,
  );

  return {
    unmount() {
      root.unmount();
      collaboration.destroy();
    },
  };
}
