/**
 * The editor is derived from Meta's Lexical playground, licensed under MIT.
 */

import './index.css';

import {createRoot} from 'react-dom/client';

import PlaygroundApp from './App';
import {createPhoenixCollaboration} from './collaboration';
import type {Collaborator} from './context/CollaborationContext';
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
  getConfirmedDocumentSnapshots(): Promise<DocumentSnapshot[]>;
  getDocumentSnapshots(): DocumentSnapshot[];
  restoreRevision(
    lexicalState: DocumentSnapshot['lexicalState'],
  ): Promise<DocumentSnapshot[]>;
  setEditable(editable: boolean): void;
  setPages(pages: WikiPageReference[]): void;
  unmount(): void;
}

export function mountLexicalEditor(
  element: HTMLElement,
  {
    collaborator,
    documentId,
    initialEditable,
    initialPages,
    wikiPageRepository,
  }: {
    collaborator: Collaborator;
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
        collaborator={collaborator}
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
    async getConfirmedDocumentSnapshots() {
      const snapshots = snapshotRegistry.snapshots();
      await collaboration.confirmUpdatesApplied();
      return snapshots;
    },
    getDocumentSnapshots() {
      return snapshotRegistry.snapshots();
    },
    async restoreRevision(lexicalState) {
      await snapshotRegistry.restoreMain(lexicalState);
      await collaboration.confirmUpdatesApplied();
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
