import {LexicalCollaboration} from '@lexical/react/LexicalCollaborationContext';
import {
  createContext,
  type JSX,
  type ReactNode,
  useContext,
  useMemo,
} from 'react';

import type {ProviderFactory} from '../collaboration';

interface CollaborationConfig {
  cursorColor: string;
  providerFactory: ProviderFactory;
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
}: {
  children: ReactNode;
  providerFactory: ProviderFactory;
}): JSX.Element {
  const config = useMemo(() => {
    const colorIndex = Math.floor(Math.random() * COLORS.length);
    const animalIndex = Math.floor(Math.random() * ANIMALS.length);
    const adjectiveIndex = Math.floor(Math.random() * ADJECTIVES.length);

    return {
      cursorColor: COLORS[colorIndex],
      providerFactory,
      username: `${ADJECTIVES[adjectiveIndex]} ${ANIMALS[animalIndex]}`,
    };
  }, [providerFactory]);

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
