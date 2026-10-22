/**
 * The editor is derived from Meta's Lexical playground, licensed under MIT.
 */

import './index.css';

import {createRoot} from 'react-dom/client';

import PlaygroundApp from './App';
import {createPhoenixCollaboration} from './collaboration';
import './setupEnv';

export interface MountedLexicalEditor {
  setEditable(editable: boolean): void;
  unmount(): void;
}

export function mountLexicalEditor(
  element: HTMLElement,
  documentId: string,
  initialEditable: boolean,
): MountedLexicalEditor {
  const collaboration = createPhoenixCollaboration(documentId);
  const root = createRoot(element);
  let editable = initialEditable;

  const render = () => {
    root.render(
      <PlaygroundApp
        editable={editable}
        providerFactory={collaboration.providerFactory}
      />,
    );
  };

  render();

  return {
    setEditable(nextEditable) {
      if (editable !== nextEditable) {
        editable = nextEditable;
        render();
      }
    },
    unmount() {
      root.unmount();
      collaboration.destroy();
    },
  };
}
