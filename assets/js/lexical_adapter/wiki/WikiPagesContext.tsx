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

export interface WikiPageSnapshot {
  contentHash: string | null;
  lexicalState: SerializedEditorState | null;
}

export interface WikiPageRepository {
  checkpoint(id: string, snapshots: DocumentSnapshot[]): Promise<boolean>;
  createCollaboration(id: string): EditorCollaboration;
  ensure(title: string): Promise<WikiPageReference>;
  loadSnapshot(id: string): Promise<WikiPageSnapshot | null>;
  resolve(id: string): Promise<WikiPageReference | null>;
}

interface WikiPagesContextValue {
  activeInlineEmbed: string | null;
  applySnapshot(id: string, snapshot: WikiPageSnapshot): void;
  beginInlineEdit(nodeKey: string): void;
  checkpointPage(id: string, snapshots: DocumentSnapshot[]): Promise<boolean>;
  collaborator: Collaborator;
  currentPageId: string;
  endInlineEdit(nodeKey: string): void;
  ensurePage(title: string): Promise<WikiPageReference>;
  integration: EditorIntegration;
  loadPageSnapshot(id: string): Promise<WikiPageSnapshot | null>;
  pageById: ReadonlyMap<string, WikiPageReference>;
  pages: WikiPageReference[];
  resolvePage(id: string): Promise<WikiPageReference | null>;
  repository: WikiPageRepository;
  snapshotByPageId: ReadonlyMap<string, WikiPageSnapshot>;
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
  snapshotUpdates = new Map(),
}: {
  children: ReactNode;
  collaborator: Collaborator;
  currentPageId: string;
  initialPages: WikiPageReference[];
  integration: EditorIntegration;
  pagePath?: string[];
  repository: WikiPageRepository;
  snapshotUpdates?: ReadonlyMap<string, WikiPageSnapshot>;
}): JSX.Element {
  const [activeInlineEmbed, setActiveInlineEmbed] = useState<string | null>(
    null,
  );
  const [pageById, setPageById] = useState(
    () => new Map(initialPages.map((page) => [page.id, page])),
  );
  const [snapshotByPageId, setSnapshotByPageId] = useState(
    () => new Map<string, WikiPageSnapshot>(),
  );
  const snapshotRequests = useRef(
    new Map<string, Promise<WikiPageSnapshot | null>>(),
  );

  useEffect(() => {
    setPageById(new Map(initialPages.map((page) => [page.id, page])));
  }, [initialPages]);

  useEffect(() => {
    if (snapshotUpdates.size === 0) {
      return;
    }

    setSnapshotByPageId((currentSnapshots) => {
      const nextSnapshots = new Map(currentSnapshots);
      snapshotUpdates.forEach((snapshot, id) => {
        if (nextSnapshots.has(id)) {
          nextSnapshots.set(id, snapshot);
        }
      });
      return nextSnapshots;
    });
  }, [snapshotUpdates]);

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

  const applySnapshot = useCallback(
    (id: string, snapshot: WikiPageSnapshot) => {
      setSnapshotByPageId((currentSnapshots) => {
        const currentSnapshot = currentSnapshots.get(id);
        if (
          snapshot.contentHash !== null &&
          currentSnapshot?.contentHash === snapshot.contentHash
        ) {
          return currentSnapshots;
        }

        const nextSnapshots = new Map(currentSnapshots);
        nextSnapshots.set(id, snapshot);
        return nextSnapshots;
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

  const loadPageSnapshot = useCallback(
    async (id: string) => {
      const cachedSnapshot = snapshotByPageId.get(id);
      if (cachedSnapshot !== undefined) {
        return cachedSnapshot;
      }

      const activeRequest = snapshotRequests.current.get(id);
      if (activeRequest !== undefined) {
        return activeRequest;
      }

      const request = repository.loadSnapshot(id).then((snapshot) => {
        snapshotRequests.current.delete(id);
        if (snapshot !== null) {
          applySnapshot(id, snapshot);
        }
        return snapshot;
      });
      snapshotRequests.current.set(id, request);
      return request;
    },
    [applySnapshot, repository, snapshotByPageId],
  );

  const beginInlineEdit = useCallback((nodeKey: string) => {
    setActiveInlineEmbed(nodeKey);
  }, []);

  const endInlineEdit = useCallback((nodeKey: string) => {
    setActiveInlineEmbed((currentNodeKey) =>
      currentNodeKey === nodeKey ? null : currentNodeKey,
    );
  }, []);

  const checkpointPage = useCallback(
    (id: string, snapshots: DocumentSnapshot[]) =>
      repository.checkpoint(id, snapshots),
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
      applySnapshot,
      beginInlineEdit,
      checkpointPage,
      collaborator,
      currentPageId,
      endInlineEdit,
      ensurePage,
      integration,
      loadPageSnapshot,
      pageById,
      pages,
      resolvePage,
      repository,
      snapshotByPageId,
    }),
    [
      activeInlineEmbed,
      applySnapshot,
      beginInlineEdit,
      checkpointPage,
      collaborator,
      currentPageId,
      endInlineEdit,
      ensurePage,
      integration,
      loadPageSnapshot,
      pageById,
      pages,
      resolvePage,
      repository,
      snapshotByPageId,
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
