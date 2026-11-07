import {defineExtension} from 'lexical';

import type {EditorIntegration} from 'live_lexical/integration';
import FloatingLinkEditorPlugin from './FloatingLinkEditorPlugin';
import {
  PageEmbedExtension,
  pageEmbedComponentPickerOptions,
} from './PageEmbedExtension';
import {PageEmbedNode} from './PageEmbedNode';
import {WikiClickableLinkExtension} from './WikiClickableLinkExtension';
import {$isWikiLinkNode, WikiLinkNode} from './WikiLinkNode';

const WikiExtension = defineExtension({
  dependencies: [PageEmbedExtension, WikiClickableLinkExtension],
  name: '@lexical/wiki',
  nodes: [WikiLinkNode],
});

export const wikiEditorIntegration: EditorIntegration = {
  componentPickerOptions: pageEmbedComponentPickerOptions,
  extension: WikiExtension,
  isLinkNode: $isWikiLinkNode,
  LinkEditorPlugin: FloatingLinkEditorPlugin,
  nodes: [PageEmbedNode, WikiLinkNode],
};
