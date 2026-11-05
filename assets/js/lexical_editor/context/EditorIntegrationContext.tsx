import {createContext, useContext} from 'react';

import type {EditorIntegration} from '../integration';

const EditorIntegrationContext = createContext<EditorIntegration | null>(null);

export const EditorIntegrationProvider =
  EditorIntegrationContext.Provider;

export function useEditorIntegration(): EditorIntegration {
  const integration = useContext(EditorIntegrationContext);

  if (integration === null) {
    throw new Error('EditorIntegrationProvider is missing');
  }

  return integration;
}
