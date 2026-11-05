import type {Collaborator} from '../lexical_editor/collaboration';
import type {
  WikiPageReference,
  WikiPageRepository,
} from './wiki/WikiPagesContext';
import {
  mountEditor,
  type MountedEditor,
} from '../lexical_editor/mount';
import {createPhoenixCollaboration} from './phoenixCollaboration';
import {wikiEditorIntegration} from './wiki/integration';
import {WikiPagesProvider} from './wiki/WikiPagesContext';

export interface MountedLexicalEditor
  extends Omit<MountedEditor, 'refresh'> {
  setPages(pages: WikiPageReference[]): void;
}

export function mountLexicalEditor(
  element: HTMLElement,
  {
    collaborator,
    csrfToken,
    documentId,
    initialEditable,
    initialPages,
    spaceId,
    wikiPageRepository,
  }: {
    collaborator: Collaborator;
    csrfToken: string;
    documentId: string;
    initialEditable: boolean;
    initialPages: WikiPageReference[];
    spaceId: string;
    wikiPageRepository: WikiPageRepository;
  },
): MountedLexicalEditor {
  const collaboration = createPhoenixCollaboration(
    documentId,
    spaceId,
    csrfToken,
  );

  let pages = initialPages;
  const editor = mountEditor(element, {
    collaboration,
    collaborator,
    initialEditable,
    integration: wikiEditorIntegration,
    renderEnvironment: children => (
      <WikiPagesProvider initialPages={pages} repository={wikiPageRepository}>
        {children}
      </WikiPagesProvider>
    ),
  });
  const {refresh, ...mountedEditor} = editor;

  return {
    ...mountedEditor,
    setPages(nextPages) {
      pages = nextPages;
      refresh();
    },
  };
}
