import type {
  AnyLexicalExtensionArgument,
  Klass,
  LexicalNode,
} from 'lexical';
import type {ComponentType, Dispatch} from 'react';

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
