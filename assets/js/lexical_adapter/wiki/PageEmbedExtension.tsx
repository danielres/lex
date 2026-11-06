import {$insertNodeToNearestRoot} from '@lexical/utils';
import {defineExtension, type LexicalEditor} from 'lexical';
import {type JSX, useMemo, useState} from 'react';

import type {ShowModal} from 'live_lexical/integration';

import {$createPageEmbedNode, PageEmbedNode} from './PageEmbedNode';
import {useWikiPages} from './WikiPagesContext';

function InsertPageEmbedDialog({
  editor,
  onClose,
}: {
  editor: LexicalEditor;
  onClose: () => void;
}): JSX.Element {
  const {currentPageId, pages} = useWikiPages();
  const [query, setQuery] = useState('');
  const [showTitle, setShowTitle] = useState(false);
  const availablePages = useMemo(() => {
    const normalizedQuery = query.trim().toLocaleLowerCase();

    return pages.filter(
      (page) =>
        page.id !== currentPageId &&
        (normalizedQuery === '' ||
          page.title.toLocaleLowerCase().includes(normalizedQuery)),
    );
  }, [currentPageId, pages, query]);

  const insert = (pageId: string) => {
    editor.update(() => {
      $insertNodeToNearestRoot($createPageEmbedNode(pageId, showTitle));
    });
    onClose();
  };

  return (
    <div className="wiki-page-embed-dialog">
      <label>
        <span>Search pages</span>
        <input
          autoFocus
          className="lexical-input"
          type="search"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
        />
      </label>
      <label className="wiki-page-embed-show-title">
        <input
          checked={showTitle}
          type="checkbox"
          onChange={(event) => setShowTitle(event.target.checked)}
        />
        Show title
      </label>
      <div className="wiki-page-embed-results">
        {availablePages.map((page) => (
          <button key={page.id} type="button" onClick={() => insert(page.id)}>
            {page.title}
          </button>
        ))}
        {availablePages.length === 0 ? <p>No pages found</p> : null}
      </div>
    </div>
  );
}

export const PageEmbedExtension = defineExtension({
  name: '@lexical/wiki/PageEmbed',
  nodes: [PageEmbedNode],
});

export function pageEmbedComponentPickerOptions(
  editor: LexicalEditor,
  showModal: ShowModal,
) {
  return [
    {
      keywords: ['page', 'embed', 'include', 'block', 'transclusion'],
      onSelect: () =>
        showModal('Embed page', (onClose: () => void) => (
          <InsertPageEmbedDialog editor={editor} onClose={onClose} />
        )),
      title: 'Page embed',
    },
  ];
}
