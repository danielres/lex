import { useLexicalComposerContext } from '@lexical/react/LexicalComposerContext';
import {
  DecoratorBlockNode,
  type SerializedDecoratorBlockNode,
} from '@lexical/react/LexicalDecoratorBlockNode';
import { useLexicalNodeSelection } from '@lexical/react/useLexicalNodeSelection';
import { useLexicalEditable } from '@lexical/react/useLexicalEditable';
import {
  $getDocument,
  $getNodeByKey,
  booleanValue,
  type DOMConversionMap,
  type EditorConfig,
  type ElementFormatType,
  type LexicalEditor,
  type LexicalNode,
  type NodeKey,
  nodeSchema,
  type Spread,
  stringValue,
  withAccessors,
} from 'lexical';
import {
  type JSX,
  type MouseEvent,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import { mountEditor, type MountedEditor } from 'live_lexical/mount';
import ReadOnlyContent from 'live_lexical/read-only-content';

import {
  PageEmbedPathProvider,
  usePageEmbedPath,
  useWikiPages,
  WikiPagesProvider,
} from './WikiPagesContext';

const MAX_PAGE_EMBED_DEPTH = 4;

const pageEmbedNodeSchema = nodeSchema<PageEmbedNode>()({
  pageId: withAccessors(stringValue(), { getter: { field: '__pageId' } }),
  showTitle: withAccessors(booleanValue(), {
    getter: { field: '__showTitle' },
  }),
});

const pageEmbedImportDOM: DOMConversionMap = {
  div: (element) => {
    const pageId = element.getAttribute('data-wiki-page-embed');
    if (pageId === null) {
      return null;
    }

    return {
      conversion: () => ({
        node: $createPageEmbedNode(
          pageId,
          element.getAttribute('data-show-title') === 'true',
        ),
      }),
      priority: 2,
    };
  },
};

function PageEmbedComponent({
  nodeKey,
  pageId,
  showTitle,
}: {
  nodeKey: NodeKey;
  pageId: string;
  showTitle: boolean;
}): JSX.Element {
  const [editor] = useLexicalComposerContext();
  const [isSelected, setSelected, clearSelection] =
    useLexicalNodeSelection(nodeKey);
  const isEditable = useLexicalEditable();
  const path = usePageEmbedPath();
  const {
    activeInlineEmbed,
    applySnapshot,
    beginInlineEdit,
    checkpointPage,
    collaborator,
    endInlineEdit,
    integration,
    loadPageSnapshot,
    pageById,
    pages,
    repository,
    snapshotByPageId,
  } = useWikiPages();
  const page = pageById.get(pageId);
  const snapshot = snapshotByPageId.get(pageId);
  const [missing, setMissing] = useState(false);
  const [saveError, setSaveError] = useState(false);
  const [saving, setSaving] = useState(false);
  const inlineEditorElement = useRef<HTMLDivElement>(null);
  const inlineEditor = useRef<MountedEditor | null>(null);
  const pagesRef = useRef(pages);
  pagesRef.current = pages;
  const inline = activeInlineEmbed === nodeKey;
  const circular = path.includes(pageId);
  const depthExceeded = path.length - 1 >= MAX_PAGE_EMBED_DEPTH;
  const embeddedPath = useMemo(() => [...path, pageId], [pageId, path]);

  useEffect(() => {
    if (circular || depthExceeded || snapshot !== undefined) {
      return;
    }

    void loadPageSnapshot(pageId).then((loadedSnapshot) => {
      setMissing(loadedSnapshot === null);
    });
  }, [circular, depthExceeded, loadPageSnapshot, pageId, snapshot]);

  useEffect(() => {
    const element = inlineEditorElement.current;
    if (!inline || element === null) {
      return;
    }

    const collaboration = repository.createCollaboration(pageId);
    const mountedEditor = mountEditor(element, {
      collaboration,
      collaborator,
      initialEditable: true,
      integration,
      renderEnvironment: (children) => (
        <WikiPagesProvider
          collaborator={collaborator}
          currentPageId={pageId}
          initialPages={pagesRef.current}
          integration={integration}
          pagePath={embeddedPath}
          repository={repository}
        >
          {children}
        </WikiPagesProvider>
      ),
    });
    inlineEditor.current = mountedEditor;

    return () => {
      inlineEditor.current = null;
      mountedEditor.unmount();
    };
  }, [collaborator, embeddedPath, inline, integration, pageId, repository]);

  const select = (event: MouseEvent) => {
    if (!isEditable || inline) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();
    clearSelection();
    setSelected(true);
  };

  const toggleTitle = () => {
    editor.update(() => {
      const node = $getNodeByKey(nodeKey);
      if ($isPageEmbedNode(node)) {
        node.setShowTitle(!showTitle);
      }
    });
  };

  const finishEditing = async () => {
    const mountedEditor = inlineEditor.current;
    if (mountedEditor === null || saving) {
      return;
    }

    setSaving(true);
    setSaveError(false);
    mountedEditor.setEditable(false);

    try {
      const snapshots = await mountedEditor.getConfirmedDocumentSnapshots();
      const saved = await checkpointPage(pageId, snapshots);

      if (saved) {
        const mainSnapshot = snapshots.find(
          (document) => document.documentKey === 'main',
        );
        if (mainSnapshot !== undefined) {
          applySnapshot(pageId, {
            contentHash: null,
            lexicalState: mainSnapshot.lexicalState,
          });
        }
        endInlineEdit(nodeKey);
      } else {
        setSaveError(true);
        mountedEditor.setEditable(true);
      }
    } finally {
      setSaving(false);
    }
  };

  const controls = (inline || (isEditable && isSelected)) && (
    <div
      className="wiki-page-embed-controls"
      onClick={(event) => event.stopPropagation()}
    >
      {isEditable ? (
        <button type="button" onClick={toggleTitle}>
          {showTitle ? 'Hide title' : 'Show title'}
        </button>
      ) : null}
      <a href={page?.path}>Open page</a>
      {inline ? (
        <button disabled={saving} type="button" onClick={finishEditing}>
          {saving ? 'Saving…' : 'Done'}
        </button>
      ) : (
        <button
          disabled={activeInlineEmbed !== null || page === undefined}
          type="button"
          onClick={() => beginInlineEdit(nodeKey)}
        >
          Edit
        </button>
      )}
      {saveError ? <span>Could not save page</span> : null}
    </div>
  );

  let content: JSX.Element;
  if (circular) {
    const chain = [...path, pageId]
      .map((id) => pageById.get(id)?.title ?? id)
      .join(' → ');
    content = (
      <div className="wiki-page-embed-message">
        Circular page embed: {chain}
      </div>
    );
  } else if (depthExceeded) {
    content = (
      <div className="wiki-page-embed-message">
        Page embed depth limit reached
      </div>
    );
  } else if (missing || page === undefined) {
    content = <div className="wiki-page-embed-message">Missing page</div>;
  } else if (inline) {
    content = (
      <div className="wiki-page-embed-editor" ref={inlineEditorElement} />
    );
  } else if (snapshot === undefined) {
    content = <div className="wiki-page-embed-message">Loading page…</div>;
  } else {
    content = (
      <PageEmbedPathProvider path={embeddedPath}>
        <ReadOnlyContent
          key={
            snapshot.contentHash ??
            JSON.stringify(snapshot.lexicalState ?? 'empty')
          }
          collaborator={collaborator}
          integration={integration}
          lexicalState={snapshot.lexicalState}
          namespace={`WikiPageEmbed/${nodeKey}/${pageId}`}
        />
      </PageEmbedPathProvider>
    );
  }

  return (
    <section
      className={`wiki-page-embed${isSelected ? ' selected' : ''}`}
      data-page-id={pageId}
      onClick={select}
    >
      {controls}
      {showTitle && page !== undefined ? (
        <div className="wiki-page-embed-title">
          <a href={page.path}>{page.title}</a>
        </div>
      ) : null}
      {content}
    </section>
  );
}

export type SerializedPageEmbedNode = Spread<
  {
    pageId: string;
    showTitle: boolean;
  },
  SerializedDecoratorBlockNode
>;

export class PageEmbedNode extends DecoratorBlockNode {
  __pageId: string;
  __showTitle: boolean;

  $config() {
    return this.config('page-embed', {
      extends: DecoratorBlockNode,
      importDOM: pageEmbedImportDOM,
      json: pageEmbedNodeSchema,
    });
  }

  static clone(node: PageEmbedNode): PageEmbedNode {
    return new PageEmbedNode(
      node.__pageId,
      node.__showTitle,
      node.__format,
      node.__key,
    );
  }

  constructor(
    pageId: string = '',
    showTitle: boolean = false,
    format?: ElementFormatType,
    key?: NodeKey,
  ) {
    super(format, key);
    this.__pageId = pageId;
    this.__showTitle = showTitle;
  }

  getPageId(): string {
    return this.getLatest().__pageId;
  }

  setPageId(pageId: string): this {
    const self = this.getWritable();
    self.__pageId = pageId;
    return self;
  }

  getShowTitle(): boolean {
    return this.getLatest().__showTitle;
  }

  setShowTitle(showTitle: boolean): this {
    const self = this.getWritable();
    self.__showTitle = showTitle;
    return self;
  }

  getTextContent(): string {
    return '';
  }

  exportDOM() {
    const element = $getDocument().createElement('div');
    element.setAttribute('data-wiki-page-embed', this.getPageId());
    element.setAttribute('data-show-title', String(this.getShowTitle()));
    return { element };
  }

  updateDOM(): false {
    return false;
  }

  decorate(_editor: LexicalEditor, _config: EditorConfig): JSX.Element {
    return (
      <PageEmbedComponent
        nodeKey={this.getKey()}
        pageId={this.getPageId()}
        showTitle={this.getShowTitle()}
      />
    );
  }
}

export function $createPageEmbedNode(
  pageId: string,
  showTitle: boolean,
): PageEmbedNode {
  return new PageEmbedNode(pageId, showTitle);
}

export function $isPageEmbedNode(
  node: LexicalNode | null | undefined,
): node is PageEmbedNode {
  return node instanceof PageEmbedNode;
}
