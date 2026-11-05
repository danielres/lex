import type {Collaborator} from '../lexical_editor/context/CollaborationContext';
import type {
  WikiPageReference,
  WikiPageRepository,
} from '../lexical_editor/context/WikiPagesContext';
import {
  mountEditor,
  type MountedLexicalEditor,
} from '../lexical_editor/mount';
import {createPhoenixCollaboration} from './phoenixCollaboration';

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

  return mountEditor(element, {
    collaboration,
    collaborator,
    initialEditable,
    initialPages,
    wikiPageRepository,
  });
}
