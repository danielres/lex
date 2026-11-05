import type {
  AnyLexicalExtensionArgument,
  Klass,
  LexicalNode,
} from 'lexical';
import {
  createContext,
  type ComponentType,
  type Dispatch,
  useContext,
} from 'react';

export interface LinkEditorPluginProps {
  anchorElem?: HTMLElement;
  isLinkEditMode: boolean;
  setIsLinkEditMode: Dispatch<boolean>;
}

export interface EditorIntegration {
  extension: AnyLexicalExtensionArgument;
  isLinkNode(node: LexicalNode): boolean;
  LinkEditorPlugin: ComponentType<LinkEditorPluginProps>;
  nodes: Klass<LexicalNode>[];
}

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
