/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import {
  autoUpdate,
  flip,
  inline,
  offset,
  shift,
  useFloating,
} from '@floating-ui/react';
import {
  $createLinkNode,
  $isAutoLinkNode,
  $isLinkNode,
  type LinkNode,
  TOGGLE_LINK_COMMAND,
} from '@lexical/link';
import {useLexicalComposerContext} from '@lexical/react/LexicalComposerContext';
import {
  $createTextNode,
  $findMatchingParent,
  $getNodeByKey,
  $getSelection,
  $isDecoratorNode,
  $isLineBreakNode,
  $isNodeSelection,
  $isRangeSelection,
  $onUpdate,
  $setSelection,
  type BaseSelection,
  CLICK_COMMAND,
  COMMAND_PRIORITY_CRITICAL,
  COMMAND_PRIORITY_HIGH,
  COMMAND_PRIORITY_LOW,
  getActiveElementDeep,
  getDOMSelection,
  getDOMSelectionPoints,
  getDOMSelectionRangeAndPoints,
  getParentElement,
  getRootOwnerDocument,
  KEY_ESCAPE_COMMAND,
  type LexicalEditor,
  mergeRegister,
  type NodeKey,
  type RangeSelection,
  registerEventListener,
  SELECTION_CHANGE_COMMAND,
} from 'lexical';
import * as React from 'react';
import {
  type Dispatch,
  type JSX,
  useCallback,
  useEffect,
  useRef,
  useState,
} from 'react';
import {createPortal} from 'react-dom';

import {
  type WikiPageReference,
  useWikiPages,
} from '../../context/WikiPagesContext';
import {$createWikiLinkNode, $isWikiLinkNode} from '../../nodes/WikiLinkNode';
import {getSelectedNode} from '../../utils/getSelectedNode';
import {sanitizeUrl} from '../../utils/url';

function $getSelectedLinkNode(selection: RangeSelection): LinkNode | null {
  const node = getSelectedNode(selection);
  // 1. Node itself is a link
  if ($isLinkNode(node)) {
    return node;
  }
  // 2. Parent is a link
  const linkParent = $findMatchingParent(node, $isLinkNode);
  if ($isLinkNode(linkParent)) {
    return linkParent;
  }
  // 3. Right-biased adjacent link (for single-char links)
  if (selection.isCollapsed()) {
    const anchor = selection.anchor;
    if (anchor.type === 'text') {
      const anchorNode = anchor.getNode();
      if (anchor.offset === anchorNode.getTextContentSize()) {
        const nextSibling = anchorNode.getNextSibling();
        if ($isLinkNode(nextSibling)) {
          return nextSibling;
        }
      }
    }
  }
  return null;
}

function preventDefault(
  event: React.KeyboardEvent<HTMLInputElement> | React.MouseEvent<HTMLElement>,
): void {
  event.preventDefault();
}

type SelectedWikiLink = {
  nodeKey: NodeKey;
  pageId: string;
};

function slugPreview(title: string): string {
  return title
    .normalize('NFC')
    .trim()
    .toLocaleLowerCase()
    .replace(/[^\p{L}\p{N}]+/gu, '-')
    .replace(/^-+|-+$/g, '');
}

function FloatingLinkEditor({
  editor,
  isLink,
  setIsLink,
  wikiLink,
  anchorElem,
  isLinkEditMode,
  setIsLinkEditMode,
}: {
  editor: LexicalEditor;
  isLink: boolean;
  setIsLink: Dispatch<boolean>;
  wikiLink: SelectedWikiLink | null;
  anchorElem: HTMLElement;
  isLinkEditMode: boolean;
  setIsLinkEditMode: Dispatch<boolean>;
}): JSX.Element {
  const editorRef = useRef<HTMLDivElement | null>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const {ensurePage, pageById, pages} = useWikiPages();
  const [linkUrl, setLinkUrl] = useState('');
  const [editedLinkUrl, setEditedLinkUrl] = useState('https://');
  const [linkMode, setLinkMode] = useState<'wiki' | 'external'>('wiki');
  const [wikiQuery, setWikiQuery] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isSaving, setIsSaving] = useState(false);
  const [lastSelection, setLastSelection] = useState<BaseSelection | null>(
    null,
  );
  const selectedWikiPage = wikiLink ? pageById.get(wikiLink.pageId) : undefined;
  const normalizedWikiQuery = wikiQuery.trim().toLocaleLowerCase();
  const matchingPages = pages
    .filter(
      page =>
        page.title.toLocaleLowerCase().includes(normalizedWikiQuery) ||
        page.slug.toLocaleLowerCase().includes(normalizedWikiQuery),
    )
    .slice(0, 8);
  const hasExactPage = pages.some(
    page =>
      page.title.toLocaleLowerCase() === normalizedWikiQuery ||
      page.slug.toLocaleLowerCase() === normalizedWikiQuery,
  );
  const visible = isLink || isLinkEditMode;

  const scrollerElem = getParentElement(anchorElem);

  const {refs, floatingStyles} = useFloating({
    middleware: [
      inline(),
      offset(10),
      flip({
        boundary: scrollerElem || undefined,
        padding: 10,
      }),
      shift({
        boundary: scrollerElem || undefined,
        crossAxis: true,
        mainAxis: true,
        padding: 10,
      }),
    ],
    placement: 'bottom-start',
    strategy: 'absolute',
    whileElementsMounted: (...args) =>
      autoUpdate(...args, {ancestorScroll: false}),
  });

  const $updateLinkEditor = useCallback(() => {
    const selection = $getSelection();
    if ($isRangeSelection(selection)) {
      const linkNode = $getSelectedLinkNode(selection);
      if (linkNode) {
        setLinkUrl(linkNode.getURL());
      } else {
        setLinkUrl('');
      }
    } else if ($isNodeSelection(selection)) {
      const nodes = selection.getNodes();
      if (nodes.length > 0) {
        const node = nodes[0];
        const parent = node.getParent();
        if ($isLinkNode(parent)) {
          setLinkUrl(parent.getURL());
        } else if ($isLinkNode(node)) {
          setLinkUrl(node.getURL());
        } else {
          setLinkUrl('');
        }
      }
    }

    const nativeSelection = getDOMSelection(editor._window);

    const rootElement = editor.getRootElement();
    // getActiveElementDeep rather than document.activeElement, which reports
    // the shadow host when the editor (or the link input) is in a shadow root.
    const activeElement = getActiveElementDeep(
      getRootOwnerDocument(rootElement),
    );

    if (selection !== null && rootElement !== null && editor.isEditable()) {
      let referenceElement: Element | null = null;

      if ($isNodeSelection(selection)) {
        const nodes = selection.getNodes();
        if (nodes.length > 0) {
          referenceElement = editor.getElementByKey(nodes[0].getKey());
        }
      } else if (
        $isRangeSelection(selection) &&
        nativeSelection !== null &&
        nativeSelection.rangeCount > 0 &&
        rootElement.contains(
          getDOMSelectionPoints(nativeSelection, rootElement).anchorNode,
        )
      ) {
        const linkNode = $getSelectedLinkNode(selection);
        if (linkNode) {
          // For decorator-only links (e.g. linked images), anchor to the
          // decorator's element since the link's line box may not match
          // the decorator's visual extent.
          const onlyChild =
            linkNode.getChildrenSize() === 1 ? linkNode.getFirstChild() : null;
          referenceElement =
            onlyChild && $isDecoratorNode(onlyChild)
              ? editor.getElementByKey(onlyChild.getKey())
              : editor.getElementByKey(linkNode.getKey());
        }
      }

      if (referenceElement) {
        // Use a virtual element exposing both rect methods so `inline`
        // can read client rects reliably.
        const refEl = referenceElement;
        refs.setPositionReference({
          getBoundingClientRect: () => refEl.getBoundingClientRect(),
          getClientRects: () => refEl.getClientRects(),
        });
      } else if (nativeSelection !== null && nativeSelection.rangeCount > 0) {
        const {points, range: selectionRange} = getDOMSelectionRangeAndPoints(
          nativeSelection,
          rootElement,
        );
        if (
          rootElement.contains(points.anchorNode) &&
          selectionRange !== null
        ) {
          refs.setPositionReference(selectionRange);
        }
      }
      setLastSelection(selection);
    } else if (!activeElement || !editorRef.current?.contains(activeElement)) {
      setLastSelection(null);
      setIsLinkEditMode(false);
      setLinkUrl('');
    }

    return true;
  }, [editor, refs, setIsLinkEditMode]);

  useEffect(() => {
    return mergeRegister(
      editor.registerUpdateListener(({editorState}) => {
        editorState.read(() => {
          $updateLinkEditor();
        });
      }),

      editor.registerCommand(
        SELECTION_CHANGE_COMMAND,
        () => {
          $onUpdate(() => editor.read('latest', $updateLinkEditor));
          return true;
        },
        COMMAND_PRIORITY_LOW,
      ),
      editor.registerCommand(
        KEY_ESCAPE_COMMAND,
        () => {
          if (visible) {
            setIsLink(false);
            setIsLinkEditMode(false);
            return true;
          }
          return false;
        },
        COMMAND_PRIORITY_HIGH,
      ),
    );
  }, [editor, $updateLinkEditor, setIsLink, setIsLinkEditMode, visible]);

  useEffect(() => {
    editor.read('latest', () => {
      $updateLinkEditor();
    });
  }, [editor, $updateLinkEditor]);

  useEffect(() => {
    if (isLinkEditMode) {
      setError(null);
      if (wikiLink) {
        setLinkMode('wiki');
        setWikiQuery(selectedWikiPage?.title ?? '');
      } else if (isLink) {
        setLinkMode('external');
        setEditedLinkUrl(linkUrl);
      } else {
        setLinkMode('wiki');
        setWikiQuery('');
        setEditedLinkUrl('https://');
      }
    }
  }, [isLink, isLinkEditMode, linkUrl, selectedWikiPage?.title, wikiLink]);

  useEffect(() => {
    if (isLinkEditMode && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isLinkEditMode, linkMode]);

  useEffect(() => {
    const editorElement = editorRef.current;
    if (editorElement === null) {
      return;
    }
    const handleBlur = (event: FocusEvent) => {
      if (!editorElement.contains(event.relatedTarget as Element) && visible) {
        setIsLink(false);
        setIsLinkEditMode(false);
      }
    };
    return registerEventListener(editorElement, 'focusout', handleBlur);
  }, [editorRef, setIsLink, setIsLinkEditMode, visible]);

  const monitorInputInteraction = (
    event: React.KeyboardEvent<HTMLInputElement>,
  ) => {
    if (event.key === 'Enter') {
      handleLinkSubmission(event);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      setIsLinkEditMode(false);
    }
  };

  const handleLinkSubmission = (
    event:
      React.KeyboardEvent<HTMLInputElement> | React.MouseEvent<HTMLElement>,
  ) => {
    event.preventDefault();
    if (lastSelection !== null && editedLinkUrl.trim() !== '') {
      editor.update(() => {
        $setSelection(lastSelection.clone());
        editor.dispatchCommand(TOGGLE_LINK_COMMAND, {
          rel: 'noopener noreferrer',
          target: '_blank',
          url: sanitizeUrl(editedLinkUrl),
        });
        const selection = $getSelection();
        if ($isRangeSelection(selection)) {
          const parent = getSelectedNode(selection).getParent();
          if ($isAutoLinkNode(parent)) {
            const linkNode = $createLinkNode(parent.getURL(), {
              rel: parent.__rel,
              target: parent.__target,
              title: parent.__title,
            });
            parent.replace(linkNode, true);
          }
        }
      });
      setEditedLinkUrl('https://');
      setIsLinkEditMode(false);
    }
  };

  const insertWikiPage = useCallback(
    (page: WikiPageReference) => {
      if (lastSelection === null) {
        return;
      }

      editor.update(() => {
        if (wikiLink) {
          const node = $getNodeByKey(wikiLink.nodeKey);
          if ($isWikiLinkNode(node)) {
            node.setPageId(page.id);
          }
        } else {
          $setSelection(lastSelection.clone());
          $getSelection()?.insertNodes([$createWikiLinkNode(page.id)]);
        }
      });
      setIsLinkEditMode(false);
      setIsLink(false);
    },
    [editor, lastSelection, setIsLink, setIsLinkEditMode, wikiLink],
  );

  const createWikiPage = useCallback(async () => {
    if (wikiQuery.trim() === '') {
      return;
    }

    setError(null);
    setIsSaving(true);
    try {
      insertWikiPage(await ensurePage(wikiQuery));
    } catch (reason) {
      setError(
        reason instanceof Error ? reason.message : 'Could not create page',
      );
    } finally {
      setIsSaving(false);
    }
  }, [ensurePage, insertWikiPage, wikiQuery]);

  const unlinkWikiPage = useCallback(() => {
    if (!wikiLink) {
      return;
    }

    editor.update(() => {
      const node = $getNodeByKey(wikiLink.nodeKey);
      if ($isWikiLinkNode(node)) {
        node.replace(
          $createTextNode(selectedWikiPage?.title ?? 'Missing page'),
        );
      }
    });
    setIsLink(false);
  }, [editor, selectedWikiPage?.title, setIsLink, wikiLink]);

  return (
    <div
      ref={el => {
        editorRef.current = el;
        refs.setFloating(el);
      }}
      className="link-editor"
      style={{
        ...floatingStyles,
        opacity: visible ? 1 : 0,
        pointerEvents: visible ? 'auto' : 'none',
      }}>
      {!visible ? null : isLinkEditMode ? (
        <div className="wiki-link-editor">
          <div className="wiki-link-tabs" role="tablist">
            <button
              aria-selected={linkMode === 'wiki'}
              onClick={() => setLinkMode('wiki')}
              role="tab"
              type="button">
              Wiki page
            </button>
            <button
              aria-selected={linkMode === 'external'}
              onClick={() => setLinkMode('external')}
              role="tab"
              type="button">
              External URL
            </button>
          </div>

          {linkMode === 'wiki' ? (
            <div className="wiki-link-page-picker">
              <input
                ref={inputRef}
                aria-label="Search or create a wiki page"
                className="link-input"
                onChange={event => setWikiQuery(event.target.value)}
                placeholder="Page title"
                value={wikiQuery}
              />
              <div className="wiki-link-results">
                {matchingPages.map(page => (
                  <button
                    key={page.id}
                    onClick={() => insertWikiPage(page)}
                    onMouseDown={preventDefault}
                    type="button">
                    <span>{page.title}</span>
                    <small>/{page.slug}</small>
                  </button>
                ))}
                {wikiQuery.trim() !== '' && !hasExactPage ? (
                  <button
                    disabled={isSaving || slugPreview(wikiQuery) === ''}
                    onClick={() => void createWikiPage()}
                    onMouseDown={preventDefault}
                    type="button">
                    <span>Create “{wikiQuery.trim()}”</span>
                    <small>/{slugPreview(wikiQuery)}</small>
                  </button>
                ) : null}
              </div>
              {error ? <p className="wiki-link-error">{error}</p> : null}
            </div>
          ) : (
            <div className="wiki-link-external-editor">
              <input
                ref={inputRef}
                aria-label="External URL"
                className="link-input"
                value={editedLinkUrl}
                onChange={event => setEditedLinkUrl(event.target.value)}
                onKeyDown={monitorInputInteraction}
              />
              <button
                onMouseDown={preventDefault}
                onClick={handleLinkSubmission}
                type="button">
                Apply
              </button>
            </div>
          )}

          <button
            className="wiki-link-cancel"
            onMouseDown={preventDefault}
            onClick={() => setIsLinkEditMode(false)}
            type="button">
            Cancel
          </button>
        </div>
      ) : (
        <div className="link-view">
          {wikiLink ? (
            <a href={selectedWikiPage?.path}>
              {selectedWikiPage?.title ?? 'Missing page'}
            </a>
          ) : (
            <a
              href={sanitizeUrl(linkUrl)}
              target="_blank"
              rel="noopener noreferrer">
              {linkUrl}
            </a>
          )}
          <div
            className="link-edit"
            role="button"
            tabIndex={0}
            onMouseDown={preventDefault}
            onClick={event => {
              event.preventDefault();
              setIsLinkEditMode(true);
            }}
          />
          <div
            className="link-trash"
            role="button"
            tabIndex={0}
            onMouseDown={preventDefault}
            onClick={() => {
              if (wikiLink) {
                unlinkWikiPage();
              } else {
                editor.dispatchCommand(TOGGLE_LINK_COMMAND, null);
              }
            }}
          />
        </div>
      )}
    </div>
  );
}

function useFloatingLinkEditorToolbar(
  editor: LexicalEditor,
  anchorElem: HTMLElement,
  isLinkEditMode: boolean,
  setIsLinkEditMode: Dispatch<boolean>,
): JSX.Element | null {
  const [activeEditor, setActiveEditor] = useState(editor);
  const [isLink, setIsLink] = useState(false);
  const [wikiLink, setWikiLink] = useState<SelectedWikiLink | null>(null);

  useEffect(() => {
    function $updateToolbar() {
      if (!editor.isEditable()) {
        // The link editor is an editing affordance (edit / delete the link),
        // and `$updateLinkEditor` does not even resolve a URL for it while the
        // editor is read-only. Clicking a link in read-only mode follows it
        // (ClickableLinkExtension), so there is nothing to pop up.
        setIsLink(false);
        setWikiLink(null);
        return;
      }
      const selection = $getSelection();
      if ($isRangeSelection(selection)) {
        setWikiLink(null);
        const focusLinkNode = $getSelectedLinkNode(selection);
        const focusNode = getSelectedNode(selection);
        const focusAutoLinkNode = $findMatchingParent(
          focusNode,
          $isAutoLinkNode,
        );
        if (!(focusLinkNode || focusAutoLinkNode)) {
          setIsLink(false);
          return;
        }
        const badNode = selection
          .getNodes()
          .filter(node => !$isLineBreakNode(node))
          .find(node => {
            const linkNode = $findMatchingParent(node, $isLinkNode);
            const autoLinkNode = $findMatchingParent(node, $isAutoLinkNode);
            return (
              (focusLinkNode && !focusLinkNode.is(linkNode)) ||
              (linkNode && !linkNode.is(focusLinkNode)) ||
              (focusAutoLinkNode && !focusAutoLinkNode.is(autoLinkNode)) ||
              (autoLinkNode &&
                (!autoLinkNode.is(focusAutoLinkNode) ||
                  autoLinkNode.getIsUnlinked()))
            );
          });
        if (!badNode) {
          setIsLink(true);
        } else {
          setIsLink(false);
        }
      } else if ($isNodeSelection(selection)) {
        const nodes = selection.getNodes();
        if (nodes.length === 0) {
          setIsLink(false);
          setWikiLink(null);
          return;
        }
        const node = nodes[0];
        const parent = node.getParent();
        if ($isWikiLinkNode(node)) {
          setWikiLink(currentWikiLink => {
            const nextWikiLink = {
              nodeKey: node.getKey(),
              pageId: node.getPageId(),
            };

            return currentWikiLink?.nodeKey === nextWikiLink.nodeKey &&
              currentWikiLink.pageId === nextWikiLink.pageId
              ? currentWikiLink
              : nextWikiLink;
          });
          setIsLink(true);
        } else if ($isLinkNode(parent) || $isLinkNode(node)) {
          setWikiLink(null);
          setIsLink(true);
        } else {
          setWikiLink(null);
          setIsLink(false);
        }
      }
    }
    return mergeRegister(
      // Close an open link editor the moment the editor becomes read-only,
      // rather than leaving the last one on screen until the next update.
      editor.registerEditableListener(editable => {
        if (!editable) {
          setIsLink(false);
          setWikiLink(null);
        }
      }),
      editor.registerUpdateListener(({editorState}) => {
        editorState.read(() => {
          $updateToolbar();
        });
      }),
      editor.registerCommand(
        SELECTION_CHANGE_COMMAND,
        (_payload, newEditor) => {
          $updateToolbar();
          setActiveEditor(newEditor);
          return false;
        },
        COMMAND_PRIORITY_CRITICAL,
      ),
      editor.registerCommand(
        CLICK_COMMAND,
        payload => {
          const selection = $getSelection();
          if ($isRangeSelection(selection)) {
            const node = getSelectedNode(selection);
            const linkNode = $findMatchingParent(node, $isLinkNode);
            if ($isLinkNode(linkNode) && (payload.metaKey || payload.ctrlKey)) {
              window.open(linkNode.getURL(), '_blank');
              return true;
            }
          }
          return false;
        },
        COMMAND_PRIORITY_LOW,
      ),
    );
  }, [editor]);

  return createPortal(
    <FloatingLinkEditor
      editor={activeEditor}
      isLink={isLink}
      anchorElem={anchorElem}
      setIsLink={setIsLink}
      wikiLink={wikiLink}
      isLinkEditMode={isLinkEditMode}
      setIsLinkEditMode={setIsLinkEditMode}
    />,
    anchorElem,
  );
}

export default function FloatingLinkEditorPlugin({
  anchorElem = document.body,
  isLinkEditMode,
  setIsLinkEditMode,
}: {
  anchorElem?: HTMLElement;
  isLinkEditMode: boolean;
  setIsLinkEditMode: Dispatch<boolean>;
}): JSX.Element | null {
  const [editor] = useLexicalComposerContext();
  return useFloatingLinkEditorToolbar(
    editor,
    anchorElem,
    isLinkEditMode,
    setIsLinkEditMode,
  );
}
