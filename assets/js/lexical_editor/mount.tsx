/**
 * The editor is derived from Meta's Lexical playground, licensed under MIT.
 */

import './index.css';

import {createRoot} from 'react-dom/client';

import PlaygroundApp from './App';
import {createPhoenixCollaboration} from './collaboration';
import type {
  WikiPageReference,
  WikiPageRepository,
} from './context/WikiPagesContext';
import './setupEnv';

export interface MountedLexicalEditor {
  setEditable(editable: boolean): void;
  unmount(): void;
}

export function mountLexicalEditor(
  element: HTMLElement,
  {
    documentId,
    initialEditable,
    initialPages,
    wikiPageRepository,
  }: {
    documentId: string;
    initialEditable: boolean;
    initialPages: WikiPageReference[];
    wikiPageRepository: WikiPageRepository;
  },
): MountedLexicalEditor {
  const collaboration = createPhoenixCollaboration(documentId);
  const root = createRoot(element);
  let editable = initialEditable;

  const render = () => {
    root.render(
      <PlaygroundApp
        editable={editable}
        initialPages={initialPages}
        providerFactory={collaboration.providerFactory}
        wikiPageRepository={wikiPageRepository}
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
