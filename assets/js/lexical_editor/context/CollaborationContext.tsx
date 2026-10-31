import {LexicalCollaboration} from '@lexical/react/LexicalCollaborationContext';
import {
  createContext,
  type JSX,
  type ReactNode,
  useContext,
  useMemo,
} from 'react';

import type {ProviderFactory} from '../collaboration';
import type {DocumentSnapshotRegistry} from '../documentSnapshots';

interface CollaborationConfig {
  collaborative: boolean;
  cursorColor: string;
  displayName: string;
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
}

export interface Collaborator {
  displayName: string;
  hue: number;
}

const CollaborationConfigContext = createContext<CollaborationConfig | null>(
  null,
);

export function CollaborationContext({
  children,
  collaborative = true,
  collaborator,
  providerFactory,
  snapshotRegistry,
}: {
  children: ReactNode;
  collaborative?: boolean;
  collaborator: Collaborator;
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
}): JSX.Element {
  const config = useMemo(
    () => ({
      collaborative,
      cursorColor:
        'oklch(var(--collaboration-color-lightness) ' +
        `var(--collaboration-color-chroma) ${collaborator.hue}deg)`,
      displayName: collaborator.displayName,
      providerFactory,
      snapshotRegistry,
    }),
    [collaborative, collaborator, providerFactory, snapshotRegistry],
  );

  return (
    <LexicalCollaboration>
      <CollaborationConfigContext.Provider value={config}>
        {children}
      </CollaborationConfigContext.Provider>
    </LexicalCollaboration>
  );
}

export function useCollaborationConfig(): CollaborationConfig {
  const config = useContext(CollaborationConfigContext);

  if (config === null) {
    throw new Error('CollaborationContext is missing');
  }

  return config;
}
