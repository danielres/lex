/**
 * The editor is derived from Meta's Lexical playground, licensed under MIT.
 */

import './fonts.css';

import {createRoot} from 'react-dom/client';
import type {ReactNode} from 'react';

import PlaygroundApp from './App';
import type {Collaborator, EditorCollaboration} from './collaboration';
import {
  type DocumentSnapshot,
  DocumentSnapshotRegistry,
} from './documentSnapshots';
import type {EditorIntegration} from './integration';
import './setupEnv';

export type {DocumentSnapshot} from './documentSnapshots';

export interface MountedEditor {
  getConfirmedDocumentSnapshots(): Promise<DocumentSnapshot[]>;
  getDocumentSnapshots(): DocumentSnapshot[];
  restoreRevision(
    lexicalState: DocumentSnapshot['lexicalState'],
  ): Promise<DocumentSnapshot[]>;
  setEditable(editable: boolean): void;
  refresh(): void;
  unmount(): void;
}

export function mountEditor(
  element: HTMLElement,
  {
    collaborator,
    collaboration,
    initialEditable,
    integration,
    renderEnvironment,
  }: {
    collaborator: Collaborator;
    collaboration: EditorCollaboration;
    initialEditable: boolean;
    integration: EditorIntegration;
    renderEnvironment: (children: ReactNode) => ReactNode;
  },
): MountedEditor {
  const snapshotRegistry = new DocumentSnapshotRegistry(initialEditable);
  const root = createRoot(element);
  let editable = initialEditable;

  const render = () => {
    const editor = (
      <PlaygroundApp
        collaborator={collaborator}
        editable={editable}
        integration={integration}
        providerFactory={collaboration.providerFactory}
        snapshotRegistry={snapshotRegistry}
      />
    );

    root.render(renderEnvironment(editor));
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
    refresh() {
      render();
    },
    unmount() {
      root.unmount();
      collaboration.destroy();
    },
  };
}
