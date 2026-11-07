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
  enumValue,
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

export type PageEmbedRenderMode = 'full' | 'headings';

type PageEmbedOptions = {
  renderMode?: PageEmbedRenderMode;
  showTitle?: boolean;
};

const pageEmbedNodeSchema = nodeSchema<PageEmbedNode>()({
  pageId: withAccessors(stringValue(), { getter: { field: '__pageId' } }),
  renderMode: withAccessors(enumValue(['full', 'headings'], 'full'), {
    getter: { field: '__renderMode' },
  }),
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
        node: $createPageEmbedNode(pageId, {
          renderMode:
            element.getAttribute('data-render-mode') === 'headings'
              ? 'headings'
              : 'full',
          showTitle: element.getAttribute('data-show-title') === 'true',
        }),
      }),
      priority: 2,
    };
  },
};

function PageEmbedComponent({
  nodeKey,
  pageId,
  renderMode,
  showTitle,
}: {
  nodeKey: NodeKey;
  pageId: string;
  renderMode: PageEmbedRenderMode;
  showTitle: boolean;
}): JSX.Element {
  const [editor] = useLexicalComposerContext();
  const [isSelected, setSelected, clearSelection] =
    useLexicalNodeSelection(nodeKey);
  const isEditable = useLexicalEditable();
  const path = usePageEmbedPath();
  const {
    activeInlineEmbed,
    applyContent,
    beginInlineEdit,
    savePage,
    collaborator,
    endInlineEdit,
    integration,
    loadPageContent,
    pageById,
    pages,
    repository,
    contentByPageId,
  } = useWikiPages();
  const page = pageById.get(pageId);
  const pageContent = contentByPageId.get(pageId);
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
    if (circular || depthExceeded || pageContent !== undefined) {
      return;
    }

    void loadPageContent(pageId).then((loadedContent) => {
      setMissing(loadedContent === null);
    });
  }, [circular, depthExceeded, loadPageContent, pageContent, pageId]);

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

  const setHeadingsOnly = (headingsOnly: boolean) => {
    editor.update(() => {
      const node = $getNodeByKey(nodeKey);
      if ($isPageEmbedNode(node)) {
        node.setRenderMode(headingsOnly ? 'headings' : 'full');
      }
    });
  };

  const setShowTitle = (showTitle: boolean) => {
    editor.update(() => {
      const node = $getNodeByKey(nodeKey);
      if ($isPageEmbedNode(node)) {
        node.setShowTitle(showTitle);
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
      const snapshots = await mountedEditor.captureDocumentSnapshots();
      const saved = await savePage(pageId, snapshots);

      if (saved) {
        const mainSnapshot = snapshots.find(
          (document) => document.documentKey === 'main',
        );
        if (mainSnapshot !== undefined) {
          applyContent(pageId, {
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
        <div className="wiki-page-embed-options">
          <label>
            <input
              checked={renderMode === 'headings'}
              type="checkbox"
              onChange={(event) => setHeadingsOnly(event.target.checked)}
            />
            Headings only
          </label>
          <label>
            <input
              checked={showTitle}
              type="checkbox"
              onChange={(event) => setShowTitle(event.target.checked)}
            />
            Show title
          </label>
        </div>
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
      {saveError ? (
        <span className="wiki-page-embed-save-error">Could not save page</span>
      ) : null}
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
  } else if (pageContent === undefined) {
    content = <div className="wiki-page-embed-message">Loading page…</div>;
  } else {
    content = (
      <PageEmbedPathProvider path={embeddedPath}>
        <ReadOnlyContent
          key={
            pageContent.contentHash ??
            JSON.stringify(pageContent.lexicalState ?? 'empty')
          }
          collaborator={collaborator}
          integration={integration}
          lexicalState={pageContent.lexicalState}
          namespace={`WikiPageEmbed/${nodeKey}/${pageId}`}
        />
      </PageEmbedPathProvider>
    );
  }

  const className = [
    'wiki-page-embed',
    renderMode === 'headings' && 'headings-only',
    isSelected && 'selected',
  ]
    .filter(Boolean)
    .join(' ');

  return (
    <section
      className={className}
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
    renderMode: PageEmbedRenderMode;
    showTitle: boolean;
  },
  SerializedDecoratorBlockNode
>;

export class PageEmbedNode extends DecoratorBlockNode {
  __pageId: string;
  __renderMode: PageEmbedRenderMode;
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
      {
        renderMode: node.__renderMode,
        showTitle: node.__showTitle,
      },
      node.__format,
      node.__key,
    );
  }

  constructor(
    pageId: string = '',
    { renderMode = 'full', showTitle = false }: PageEmbedOptions = {},
    format?: ElementFormatType,
    key?: NodeKey,
  ) {
    super(format, key);
    this.__pageId = pageId;
    this.__renderMode = renderMode;
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

  getRenderMode(): PageEmbedRenderMode {
    return this.getLatest().__renderMode;
  }

  setRenderMode(renderMode: PageEmbedRenderMode): this {
    const self = this.getWritable();
    self.__renderMode = renderMode;
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
    element.setAttribute('data-render-mode', this.getRenderMode());
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
        renderMode={this.getRenderMode()}
        showTitle={this.getShowTitle()}
      />
    );
  }
}

export function $createPageEmbedNode(
  pageId: string,
  options: PageEmbedOptions = {},
): PageEmbedNode {
  return new PageEmbedNode(pageId, options);
}

export function $isPageEmbedNode(
  node: LexicalNode | null | undefined,
): node is PageEmbedNode {
  return node instanceof PageEmbedNode;
}
