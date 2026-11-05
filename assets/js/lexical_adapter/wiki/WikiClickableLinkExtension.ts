import {defineExtension, type LexicalEditor} from 'lexical';

function closestAnchor(target: EventTarget | null): HTMLAnchorElement | null {
  return target instanceof Element ? target.closest('a') : null;
}

function registerWikiClickableLinks(editor: LexicalEditor): () => void {
  const onClick = (event: MouseEvent) => {
    if (
      editor.isEditable() ||
      (event.type === 'auxclick' && event.button !== 1)
    ) {
      return;
    }

    const anchor = closestAnchor(event.target);
    if (!anchor?.href) {
      return;
    }

    const selection = window.getSelection();
    if (selection && !selection.isCollapsed) {
      event.preventDefault();
      event.stopPropagation();
      return;
    }

    if (anchor.dataset.phxLink === 'patch') {
      return;
    }

    window.open(anchor.href, '_blank');
    event.preventDefault();
  };

  return editor.registerRootListener((rootElement, previousRootElement) => {
    previousRootElement?.removeEventListener('click', onClick);
    previousRootElement?.removeEventListener('auxclick', onClick);
    rootElement?.addEventListener('click', onClick);
    rootElement?.addEventListener('auxclick', onClick);
  });
}

/**
 * Restores links in a read-only editor while leaving Phoenix patch links for
 * LiveView's document-level click handler.
 */
export const WikiClickableLinkExtension = defineExtension({
  name: '@lexical/wiki/ClickableLink',
  register: registerWikiClickableLinks,
});
