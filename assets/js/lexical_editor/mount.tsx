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
import {
  type DocumentSnapshot,
  DocumentSnapshotRegistry,
} from './documentSnapshots';
import './setupEnv';

export interface MountedLexicalEditor {
  getDocumentSnapshots(): DocumentSnapshot[];
  setEditable(editable: boolean): void;
  setPages(pages: WikiPageReference[]): void;
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
  const snapshotRegistry = new DocumentSnapshotRegistry(initialEditable);
  const root = createRoot(element);
  let editable = initialEditable;
  let pages = initialPages;

  const render = () => {
    root.render(
      <PlaygroundApp
        editable={editable}
        initialPages={pages}
        providerFactory={collaboration.providerFactory}
        snapshotRegistry={snapshotRegistry}
        wikiPageRepository={wikiPageRepository}
      />,
    );
  };

  render();

  return {
    getDocumentSnapshots() {
      return snapshotRegistry.snapshots();
    },
    setEditable(nextEditable) {
      if (editable !== nextEditable) {
        editable = nextEditable;
        snapshotRegistry.setEditable(editable);
        render();
      }
    },
    setPages(nextPages) {
      pages = nextPages;
      render();
    },
    unmount() {
      root.unmount();
      collaboration.destroy();
    },
  };
}
