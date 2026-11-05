import {defineExtension} from 'lexical';

import type {EditorIntegration} from '../../lexical_editor/context/EditorIntegrationContext';
import FloatingLinkEditorPlugin from './FloatingLinkEditorPlugin';
import {WikiClickableLinkExtension} from './WikiClickableLinkExtension';
import {$isWikiLinkNode, WikiLinkNode} from './WikiLinkNode';

const WikiExtension = defineExtension({
  dependencies: [WikiClickableLinkExtension],
  name: '@lexical/wiki',
  nodes: [WikiLinkNode],
});

export const wikiEditorIntegration: EditorIntegration = {
  extension: WikiExtension,
  isLinkNode: $isWikiLinkNode,
  LinkEditorPlugin: FloatingLinkEditorPlugin,
  nodes: [WikiLinkNode],
};
