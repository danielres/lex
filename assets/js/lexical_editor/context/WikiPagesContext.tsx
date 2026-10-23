import {
  createContext,
  type JSX,
  type ReactNode,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';

export interface WikiPageReference {
  id: string;
  path: string;
  slug: string;
  title: string;
}

export interface WikiPageRepository {
  ensure(title: string): Promise<WikiPageReference>;
  resolve(id: string): Promise<WikiPageReference | null>;
}

interface WikiPagesContextValue {
  ensurePage(title: string): Promise<WikiPageReference>;
  pages: WikiPageReference[];
  resolvePage(id: string): Promise<WikiPageReference | null>;
  pageById: ReadonlyMap<string, WikiPageReference>;
}

const WikiPagesContext = createContext<WikiPagesContextValue | null>(null);

export function WikiPagesProvider({
  children,
  initialPages,
  repository,
}: {
  children: ReactNode;
  initialPages: WikiPageReference[];
  repository: WikiPageRepository;
}): JSX.Element {
  const [pageById, setPageById] = useState(
    () => new Map(initialPages.map(page => [page.id, page])),
  );

  useEffect(() => {
    setPageById(new Map(initialPages.map(page => [page.id, page])));
  }, [initialPages]);

  const rememberPage = useCallback((page: WikiPageReference) => {
    setPageById(currentPages => {
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

  const value = useMemo(
    () => ({
      ensurePage,
      pageById,
      pages: Array.from(pageById.values()).sort((left, right) =>
        left.title.localeCompare(right.title),
      ),
      resolvePage,
    }),
    [ensurePage, pageById, resolvePage],
  );

  return (
    <WikiPagesContext.Provider value={value}>
      {children}
    </WikiPagesContext.Provider>
  );
}

export function useWikiPages(): WikiPagesContextValue {
  const context = useContext(WikiPagesContext);

  if (context === null) {
    throw new Error('WikiPagesProvider is missing');
  }

  return context;
}
