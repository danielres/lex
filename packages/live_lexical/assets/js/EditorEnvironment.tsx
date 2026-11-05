import type {JSX, ReactNode} from 'react';
import {useMemo} from 'react';

import type {Collaborator, ProviderFactory} from './collaboration';
import {CollaborationContext} from './context/CollaborationContext';
import {FlashMessageContext} from './context/FlashMessageContext';
import {SettingsContext} from './context/SettingsContext';
import {DocumentSnapshotRegistry} from './documentSnapshots';

const readOnlyProviderFactory: ProviderFactory = () => {
  throw new Error('Read-only editors do not create collaboration providers');
};

function EditorEnvironment({
  children,
  collaborative,
  collaborator,
  providerFactory,
  snapshotRegistry,
}: {
  children: ReactNode;
  collaborative: boolean;
  collaborator: Collaborator;
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
}): JSX.Element {
  return (
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
  );
}

export function CollaborativeEditorEnvironment({
  children,
  collaborator,
  providerFactory,
  snapshotRegistry,
}: {
  children: ReactNode;
  collaborator: Collaborator;
  providerFactory: ProviderFactory;
  snapshotRegistry: DocumentSnapshotRegistry;
}): JSX.Element {
  return (
    <EditorEnvironment
      collaborative={true}
      collaborator={collaborator}
      providerFactory={providerFactory}
      snapshotRegistry={snapshotRegistry}
    >
      {children}
    </EditorEnvironment>
  );
}

export function ReadOnlyEditorEnvironment({
  children,
  collaborator,
}: {
  children: ReactNode;
  collaborator: Collaborator;
}): JSX.Element {
  const snapshotRegistry = useMemo(
    () => new DocumentSnapshotRegistry(false),
    [],
  );

  return (
    <EditorEnvironment
      collaborative={false}
      collaborator={collaborator}
      providerFactory={readOnlyProviderFactory}
      snapshotRegistry={snapshotRegistry}
    >
      {children}
    </EditorEnvironment>
  );
}
