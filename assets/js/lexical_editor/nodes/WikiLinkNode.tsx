import {useLexicalComposerContext} from '@lexical/react/LexicalComposerContext';
import {useLexicalNodeSelection} from '@lexical/react/useLexicalNodeSelection';
import {
  $getDocument,
  $getState,
  $setState,
  createState,
  DecoratorNode,
  type DOMExportOutput,
  type LexicalNode,
  type NodeKey,
  type StateConfigValue,
} from 'lexical';
import {type JSX, useEffect} from 'react';

import {useWikiPages} from '../context/WikiPagesContext';

const pageIdState = createState('pageId', {
  parse: value => (typeof value === 'string' ? value : ''),
});

function WikiLinkComponent({
  nodeKey,
  pageId,
}: {
  nodeKey: NodeKey;
  pageId: string;
}): JSX.Element {
  const [editor] = useLexicalComposerContext();
  const [, setSelected, clearSelection] = useLexicalNodeSelection(nodeKey);
  const {pageById, resolvePage} = useWikiPages();
  const page = pageById.get(pageId);

  useEffect(() => {
    if (!page) {
      void resolvePage(pageId);
    }
  }, [page, pageId, resolvePage]);

  return (
    <a
      className="wiki-link"
      data-page-id={pageId}
      data-phx-link={page ? 'patch' : undefined}
      data-phx-link-state={page ? 'push' : undefined}
      href={page?.path}
      onClick={event => {
        if (editor.isEditable()) {
          event.preventDefault();
          event.stopPropagation();
          clearSelection();
          setSelected(true);
        }
      }}>
      {page?.title ?? 'Missing page'}
    </a>
  );
}

export class WikiLinkNode extends DecoratorNode<JSX.Element> {
  $config() {
    return this.config('wiki-link', {
      extends: DecoratorNode,
      stateConfigs: [{flat: true, stateConfig: pageIdState}],
    });
  }

  getPageId(): StateConfigValue<typeof pageIdState> {
    return $getState(this, pageIdState);
  }

  setPageId(pageId: string): this {
    return $setState(this, pageIdState, pageId);
  }

  createDOM(): HTMLElement {
    const element = $getDocument().createElement('span');
    element.style.display = 'inline';
    return element;
  }

  updateDOM(): false {
    return false;
  }

  exportDOM(): DOMExportOutput {
    const element = $getDocument().createElement('a');
    element.setAttribute('data-wiki-page-id', this.getPageId());
    return {element};
  }

  decorate(): JSX.Element {
    return <WikiLinkComponent nodeKey={this.__key} pageId={this.getPageId()} />;
  }
}

export function $createWikiLinkNode(pageId: string): WikiLinkNode {
  return new WikiLinkNode().setPageId(pageId);
}

export function $isWikiLinkNode(
  node: LexicalNode | null | undefined,
): node is WikiLinkNode {
  return node instanceof WikiLinkNode;
}
