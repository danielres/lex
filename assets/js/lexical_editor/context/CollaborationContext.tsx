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
  cursorColor: string;
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
  username: string;
}

const CollaborationConfigContext = createContext<CollaborationConfig | null>(
  null,
);

const COLORS = ['#d13b40', '#2f7dd1', '#2f9b65', '#8a55c5', '#d27619'];
const ADJECTIVES = ['Bright', 'Calm', 'Curious', 'Kind', 'Swift'];
const ANIMALS = ['Badger', 'Fox', 'Heron', 'Otter', 'Wren'];

export function CollaborationContext({
  children,
  providerFactory,
  snapshotRegistry,
}: {
  children: ReactNode;
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
}): JSX.Element {
  const config = useMemo(() => {
    const colorIndex = Math.floor(Math.random() * COLORS.length);
    const animalIndex = Math.floor(Math.random() * ANIMALS.length);
    const adjectiveIndex = Math.floor(Math.random() * ADJECTIVES.length);

    return {
      cursorColor: COLORS[colorIndex],
      providerFactory,
      snapshotRegistry,
      username: `${ADJECTIVES[adjectiveIndex]} ${ANIMALS[animalIndex]}`,
    };
  }, [providerFactory, snapshotRegistry]);

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
