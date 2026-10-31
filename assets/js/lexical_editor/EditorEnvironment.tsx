import type {JSX, ReactNode} from 'react';
import {useMemo} from 'react';

import type {ProviderFactory} from './collaboration';
import {
  type Collaborator,
  CollaborationContext,
} from './context/CollaborationContext';
import {FlashMessageContext} from './context/FlashMessageContext';
import {SettingsContext} from './context/SettingsContext';
import {
  type WikiPageReference,
  type WikiPageRepository,
  WikiPagesProvider,
} from './context/WikiPagesContext';
import {DocumentSnapshotRegistry} from './documentSnapshots';

const readOnlyProviderFactory: ProviderFactory = () => {
  throw new Error('Read-only editors do not create collaboration providers');
};

const readOnlyWikiPageRepository: WikiPageRepository = {
  ensure: async () => {
    throw new Error('Read-only editors cannot create pages');
  },
  resolve: async () => null,
};

function EditorEnvironment({
  children,
  collaborative,
  collaborator,
  pages,
  providerFactory,
  snapshotRegistry,
  wikiPageRepository,
}: {
  children: ReactNode;
  collaborative: boolean;
  collaborator: Collaborator;
  pages: WikiPageReference[];
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
  wikiPageRepository: WikiPageRepository;
}): JSX.Element {
  return (
    <WikiPagesProvider initialPages={pages} repository={wikiPageRepository}>
      <CollaborationContext
        collaborative={collaborative}
        collaborator={collaborator}
        providerFactory={providerFactory}
        snapshotRegistry={snapshotRegistry}
      >
        <SettingsContext>
          <FlashMessageContext>{children}</FlashMessageContext>
        </SettingsContext>
      </CollaborationContext>
    </WikiPagesProvider>
  );
}

export function CollaborativeEditorEnvironment({
  children,
  collaborator,
  pages,
  providerFactory,
  snapshotRegistry,
  wikiPageRepository,
}: {
  children: ReactNode;
  collaborator: Collaborator;
  pages: WikiPageReference[];
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
  wikiPageRepository: WikiPageRepository;
}): JSX.Element {
  return (
    <EditorEnvironment
      collaborative={true}
      collaborator={collaborator}
      pages={pages}
      providerFactory={providerFactory}
      snapshotRegistry={snapshotRegistry}
      wikiPageRepository={wikiPageRepository}
    >
      {children}
    </EditorEnvironment>
  );
}

export function ReadOnlyEditorEnvironment({
  children,
  collaborator,
  pages,
}: {
  children: ReactNode;
  collaborator: Collaborator;
  pages: WikiPageReference[];
}): JSX.Element {
  const snapshotRegistry = useMemo(
    () => new DocumentSnapshotRegistry(false),
    [],
  );

  return (
    <EditorEnvironment
      collaborative={false}
      collaborator={collaborator}
      pages={pages}
      providerFactory={readOnlyProviderFactory}
      snapshotRegistry={snapshotRegistry}
      wikiPageRepository={readOnlyWikiPageRepository}
    >
      {children}
    </EditorEnvironment>
  );
}
