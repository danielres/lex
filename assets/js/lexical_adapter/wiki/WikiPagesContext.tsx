import type {SerializedEditorState} from 'lexical';
import {
  createContext,
  type JSX,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import type {
  Collaborator,
  EditorCollaboration,
} from 'live_lexical/collaboration';
import type {EditorIntegration} from 'live_lexical/integration';
import type {DocumentSnapshot} from 'live_lexical/mount';

export interface WikiPageReference {
  id: string;
  path: string;
  slug: string;
  title: string;
}

export interface WikiPageContent {
  contentHash: string | null;
  lexicalState: SerializedEditorState | null;
}

export interface WikiPageRepository {
  save(id: string, snapshots: DocumentSnapshot[]): Promise<boolean>;
  createCollaboration(id: string): EditorCollaboration;
  ensure(title: string): Promise<WikiPageReference>;
  loadContent(id: string): Promise<WikiPageContent | null>;
  resolve(id: string): Promise<WikiPageReference | null>;
}

interface WikiPagesContextValue {
  activeInlineEmbed: string | null;
  applyContent(id: string, content: WikiPageContent): void;
  beginInlineEdit(nodeKey: string): void;
  collaborator: Collaborator;
  contentByPageId: ReadonlyMap<string, WikiPageContent>;
  currentPageId: string;
  endInlineEdit(nodeKey: string): void;
  ensurePage(title: string): Promise<WikiPageReference>;
  integration: EditorIntegration;
  loadPageContent(id: string): Promise<WikiPageContent | null>;
  pageById: ReadonlyMap<string, WikiPageReference>;
  pages: WikiPageReference[];
  resolvePage(id: string): Promise<WikiPageReference | null>;
  repository: WikiPageRepository;
  savePage(id: string, snapshots: DocumentSnapshot[]): Promise<boolean>;
}

const WikiPagesContext = createContext<WikiPagesContextValue | null>(null);
const PageEmbedPathContext = createContext<string[]>([]);

export function PageEmbedPathProvider({
  children,
  path,
}: {
  children: ReactNode;
  path: string[];
}): JSX.Element {
  return (
    <PageEmbedPathContext.Provider value={path}>
      {children}
    </PageEmbedPathContext.Provider>
  );
}

export function WikiPagesProvider({
  children,
  collaborator,
  currentPageId,
  initialPages,
  integration,
  pagePath,
  repository,
  contentUpdates = new Map(),
}: {
  children: ReactNode;
  collaborator: Collaborator;
  currentPageId: string;
  initialPages: WikiPageReference[];
  integration: EditorIntegration;
  pagePath?: string[];
  repository: WikiPageRepository;
  contentUpdates?: ReadonlyMap<string, WikiPageContent>;
}): JSX.Element {
  const [activeInlineEmbed, setActiveInlineEmbed] = useState<string | null>(
    null,
  );
  const [pageById, setPageById] = useState(
    () => new Map(initialPages.map((page) => [page.id, page])),
  );
  const [contentByPageId, setContentByPageId] = useState(
    () => new Map<string, WikiPageContent>(),
  );
  const contentRequests = useRef(
    new Map<string, Promise<WikiPageContent | null>>(),
  );

  useEffect(() => {
    setPageById(new Map(initialPages.map((page) => [page.id, page])));
  }, [initialPages]);

  useEffect(() => {
    if (contentUpdates.size === 0) {
      return;
    }

    setContentByPageId((currentContent) => {
      const nextContent = new Map(currentContent);
      contentUpdates.forEach((content, id) => {
        if (nextContent.has(id)) {
          nextContent.set(id, content);
        }
      });
      return nextContent;
    });
  }, [contentUpdates]);

  const rememberPage = useCallback((page: WikiPageReference) => {
    setPageById((currentPages) => {
      const currentPage = currentPages.get(page.id);
      if (
        currentPage?.path === page.path &&
        currentPage.slug === page.slug &&
        currentPage.title === page.title
      ) {
        return currentPages;
      }

      const nextPages = new Map(currentPages);
      nextPages.set(page.id, page);
      return nextPages;
    });
    return page;
  }, []);

  const applyContent = useCallback(
    (id: string, content: WikiPageContent) => {
      setContentByPageId((currentContent) => {
        const existingContent = currentContent.get(id);
        if (
          content.contentHash !== null &&
          existingContent?.contentHash === content.contentHash
        ) {
          return currentContent;
        }

        const nextContent = new Map(currentContent);
        nextContent.set(id, content);
        return nextContent;
      });
    },
    [],
  );

  const ensurePage = useCallback(
    async (title: string) => rememberPage(await repository.ensure(title)),
    [rememberPage, repository],
  );

  const resolvePage = useCallback(
    async (id: string) => {
      const cachedPage = pageById.get(id);
      if (cachedPage) {
        return cachedPage;
      }

      const page = await repository.resolve(id);
      return page ? rememberPage(page) : null;
    },
    [pageById, rememberPage, repository],
  );

  const loadPageContent = useCallback(
    async (id: string) => {
      const cachedContent = contentByPageId.get(id);
      if (cachedContent !== undefined) {
        return cachedContent;
      }

      const activeRequest = contentRequests.current.get(id);
      if (activeRequest !== undefined) {
        return activeRequest;
      }

      const request = repository.loadContent(id).then((content) => {
        contentRequests.current.delete(id);
        if (content !== null) {
          applyContent(id, content);
        }
        return content;
      });
      contentRequests.current.set(id, request);
      return request;
    },
    [applyContent, contentByPageId, repository],
  );

  const beginInlineEdit = useCallback((nodeKey: string) => {
    setActiveInlineEmbed(nodeKey);
  }, []);

  const endInlineEdit = useCallback((nodeKey: string) => {
    setActiveInlineEmbed((currentNodeKey) =>
      currentNodeKey === nodeKey ? null : currentNodeKey,
    );
  }, []);

  const savePage = useCallback(
    (id: string, snapshots: DocumentSnapshot[]) => repository.save(id, snapshots),
    [repository],
  );

  const pages = useMemo(
    () =>
      Array.from(pageById.values()).sort((left, right) =>
        left.title.localeCompare(right.title),
      ),
    [pageById],
  );
  const embedPath = useMemo(
    () => pagePath ?? [currentPageId],
    [currentPageId, pagePath],
  );

  const value = useMemo(
    () => ({
      activeInlineEmbed,
      applyContent,
      beginInlineEdit,
      collaborator,
      contentByPageId,
      currentPageId,
      endInlineEdit,
      ensurePage,
      integration,
      loadPageContent,
      pageById,
      pages,
      resolvePage,
      repository,
      savePage,
    }),
    [
      activeInlineEmbed,
      applyContent,
      beginInlineEdit,
      collaborator,
      contentByPageId,
      currentPageId,
      endInlineEdit,
      ensurePage,
      integration,
      loadPageContent,
      pageById,
      pages,
      resolvePage,
      repository,
      savePage,
    ],
  );

  return (
    <WikiPagesContext.Provider value={value}>
      <PageEmbedPathProvider path={embedPath}>{children}</PageEmbedPathProvider>
    </WikiPagesContext.Provider>
  );
}

export function usePageEmbedPath(): string[] {
  return useContext(PageEmbedPathContext);
}

export function useWikiPages(): WikiPagesContextValue {
  const context = useContext(WikiPagesContext);

  if (context === null) {
    throw new Error('WikiPagesProvider is missing');
  }

  return context;
}
