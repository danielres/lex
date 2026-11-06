import type {
  AnyLexicalExtensionArgument,
  Klass,
  LexicalEditor,
  LexicalNode,
} from 'lexical';
import type {ComponentType, Dispatch, JSX} from 'react';

export interface ComponentPickerOptionConfig {
  icon?: JSX.Element;
  keywords?: string[];
  onSelect: (queryString: string) => void;
  title: string;
}

export type ShowModal = (
  title: string,
  getContent: (onClose: () => void) => JSX.Element,
) => void;

export interface LinkEditorPluginProps {
  anchorElem?: HTMLElement;
  isLinkEditMode: boolean;
  setIsLinkEditMode: Dispatch<boolean>;
}

export interface EditorIntegration {
  componentPickerOptions?: (
    editor: LexicalEditor,
    showModal: ShowModal,
  ) => ComponentPickerOptionConfig[];
  extension: AnyLexicalExtensionArgument;
  isLinkNode(node: LexicalNode): boolean;
  LinkEditorPlugin: ComponentType<LinkEditorPluginProps>;
  nodes: Klass<LexicalNode>[];
}
