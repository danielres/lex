/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import {useMergeRefs} from '@floating-ui/react';
import {$isCodeNode} from '@lexical/code';
import {
  getCodeLanguageOptions as getCodeLanguageOptionsPrism,
  normalizeCodeLanguage as normalizeCodeLanguagePrism,
} from '@lexical/code-prism';
import {
  getCodeLanguageOptions as getCodeLanguageOptionsShiki,
  getCodeThemeOptions as getCodeThemeOptionsShiki,
  normalizeCodeLanguage as normalizeCodeLanguageShiki,
} from '@lexical/code-shiki';
import {INSERT_HORIZONTAL_RULE_COMMAND} from '@lexical/extension';
import {$isLinkNode, TOGGLE_LINK_COMMAND} from '@lexical/link';
import {$isListNode, ListNode} from '@lexical/list';
import {INSERT_EMBED_COMMAND} from '@lexical/react/LexicalAutoEmbedPlugin';
import {useLexicalFocusManagerRef} from '@lexical/react/useLexicalFocusManagerRef';
import {useLexicalRovingTabIndexRef} from '@lexical/react/useLexicalRovingTabIndexRef';
import {$isHeadingNode} from '@lexical/rich-text';
import {$isParentElementRTL} from '@lexical/selection';
import {$isTableNode, $isTableSelection} from '@lexical/table';
import {$getNearestNodeOfType, $isEditorIsNestedEditor} from '@lexical/utils';
import {
  $addUpdateTag,
  $findMatchingParent,
  $getNodeByKey,
  $getRoot,
  $getSelection,
  $isNodeSelection,
  $isRangeSelection,
  $isRootOrShadowRoot,
  $onUpdate,
  type AnyLexicalCommand,
  CAN_REDO_COMMAND,
  CAN_UNDO_COMMAND,
  COMMAND_PRIORITY_CRITICAL,
  type CommandPayloadType,
  FORMAT_TEXT_COMMAND,
  INDENT_CONTENT_COMMAND,
  IS_APPLE,
  type LexicalEditor,
  type LexicalNode,
  mergeRegister,
  type NodeKey,
  OUTDENT_CONTENT_COMMAND,
  REDO_COMMAND,
  SELECTION_CHANGE_COMMAND,
  SKIP_DOM_SELECTION_TAG,
  SKIP_SELECTION_FOCUS_TAG,
  type TextFormatType,
  UNDO_COMMAND,
} from 'lexical';
import {type Dispatch, type JSX, useCallback, useEffect, useState} from 'react';

import {useSettings} from '../../context/SettingsContext';
import {useEditorIntegration} from '../../context/EditorIntegrationContext';
import {
  blockTypeToBlockName,
  useToolbarState,
} from '../../context/ToolbarContext';
import useModal from '../../hooks/useModal';
import catTypingGif from '../../images/cat-typing.gif';
import {$createStickyNode} from '../../nodes/StickyNode';
import DropDown, {DropDownItem} from '../../ui/DropDown';
import {isKeyboardInput} from '../../utils/focusUtils';
import {getSelectedNode} from '../../selection';
import {EmbedConfigs} from '../AutoEmbedPlugin';
import {INSERT_COLLAPSIBLE_COMMAND} from '../CollapsibleExtension';
import {INSERT_DATETIME_COMMAND} from '../DateTimeExtension';
import {InsertEquationDialog} from '../EquationsExtension';
import {INSERT_EXCALIDRAW_COMMAND} from '../ExcalidrawExtension';
import {
  INSERT_IMAGE_COMMAND,
  InsertImageDialog,
  type InsertImagePayload,
} from '../ImagesExtension';
import InsertLayoutDialog from '../LayoutExtension/InsertLayoutDialog';
import {InsertPollDialog} from '../PollExtension';
import {shortcut} from '../ShortcutsExtension/shortcuts';
import {InsertTableDialog} from '../TablePlugin';
import {
  clearFormatting,
  formatBulletList,
  formatCheckList,
  formatCode,
  formatHeading,
  formatNumberedList,
  formatParagraph,
  formatQuote,
} from './utils';

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const rootTypeToRootName = {
  root: 'Root',
  table: 'Table',
};

const CODE_LANGUAGE_OPTIONS_PRISM: [string, string][] =
  getCodeLanguageOptionsPrism().filter(option =>
    [
      'c',
      'clike',
      'cpp',
      'css',
      'go',
      'html',
      'java',
      'js',
      'javascript',
      'markdown',
      'objc',
      'objective-c',
      'plain',
      'powershell',
      'py',
      'python',
      'rust',
      'sql',
      'swift',
      'typescript',
      'xml',
    ].includes(option[0]),
  );

const CODE_LANGUAGE_OPTIONS_SHIKI: [string, string][] =
  getCodeLanguageOptionsShiki().filter(option =>
    [
      'c',
      'clike',
      'cpp',
      'css',
      'go',
      'html',
      'java',
      'js',
      'javascript',
      'markdown',
      'objc',
      'objective-c',
      'plain',
      'powershell',
      'py',
      'python',
      'rust',
      'sql',
      'typescript',
      'xml',
    ].includes(option[0]),
  );

const CODE_THEME_OPTIONS_SHIKI: [string, string][] =
  getCodeThemeOptionsShiki().filter(option =>
    [
      'catppuccin-latte',
      'everforest-light',
      'github-light',
      'gruvbox-light-medium',
      'kanagawa-lotus',
      'dark-plus',
      'light-plus',
      'material-theme-lighter',
      'min-light',
      'one-light',
      'rose-pine-dawn',
      'slack-ochin',
      'snazzy-light',
      'solarized-light',
      'vitesse-light',
    ].includes(option[0]),
  );

function dropDownActiveClass(active: boolean) {
  if (active) {
    return 'active dropdown-item-active';
  } else {
    return '';
  }
}

function BlockFormatDropDown({
  editor,
  blockType,
  rootType,
  disabled = false,
}: {
  blockType: keyof typeof blockTypeToBlockName;
  rootType: keyof typeof rootTypeToRootName;
  editor: LexicalEditor;
  disabled?: boolean;
}): JSX.Element {
  return (
    <DropDown
      disabled={disabled}
      buttonClassName="lexical-toolbar-item block-controls"
      buttonIconClassName={'icon block-type ' + blockType}
      buttonLabel={blockTypeToBlockName[blockType]}
      buttonAriaLabel="Formatting options for text style">
      <DropDownItem
        className={
          'item wide ' + dropDownActiveClass(blockType === 'paragraph')
        }
        onClick={() => formatParagraph(editor)}>
        <div className="icon-text-container">
          <i className="icon paragraph" />
          <span className="text">Normal</span>
        </div>
        <span className="shortcut">{shortcut('NORMAL')}</span>
      </DropDownItem>
      <DropDownItem
        className={'item wide ' + dropDownActiveClass(blockType === 'h1')}
        onClick={() => formatHeading(editor, blockType, 'h1')}>
        <div className="icon-text-container">
          <i className="icon h1" />
          <span className="text">Heading 1</span>
        </div>
        <span className="shortcut">{shortcut('HEADING1')}</span>
      </DropDownItem>
      <DropDownItem
        className={'item wide ' + dropDownActiveClass(blockType === 'h2')}
        onClick={() => formatHeading(editor, blockType, 'h2')}>
        <div className="icon-text-container">
          <i className="icon h2" />
          <span className="text">Heading 2</span>
        </div>
        <span className="shortcut">{shortcut('HEADING2')}</span>
      </DropDownItem>
      <DropDownItem
        className={'item wide ' + dropDownActiveClass(blockType === 'h3')}
        onClick={() => formatHeading(editor, blockType, 'h3')}>
        <div className="icon-text-container">
          <i className="icon h3" />
          <span className="text">Heading 3</span>
        </div>
        <span className="shortcut">{shortcut('HEADING3')}</span>
      </DropDownItem>
      <DropDownItem
        className={'item wide ' + dropDownActiveClass(blockType === 'number')}
        onClick={() => formatNumberedList(editor, blockType)}>
        <div className="icon-text-container">
          <i className="icon numbered-list" />
          <span className="text">Numbered List</span>
        </div>
        <span className="shortcut">{shortcut('NUMBERED_LIST')}</span>
      </DropDownItem>
      <DropDownItem
        className={'item wide ' + dropDownActiveClass(blockType === 'bullet')}
        onClick={() => formatBulletList(editor, blockType)}>
        <div className="icon-text-container">
          <i className="icon bullet-list" />
          <span className="text">Bullet List</span>
        </div>
        <span className="shortcut">{shortcut('BULLET_LIST')}</span>
      </DropDownItem>
      <DropDownItem
        className={'item wide ' + dropDownActiveClass(blockType === 'check')}
        onClick={() => formatCheckList(editor, blockType)}>
        <div className="icon-text-container">
          <i className="icon check-list" />
          <span className="text">Check List</span>
        </div>
        <span className="shortcut">{shortcut('CHECK_LIST')}</span>
      </DropDownItem>
      <DropDownItem
        className={'item wide ' + dropDownActiveClass(blockType === 'quote')}
        onClick={() => formatQuote(editor, blockType)}>
        <div className="icon-text-container">
          <i className="icon quote" />
          <span className="text">Quote</span>
        </div>
        <span className="shortcut">{shortcut('QUOTE')}</span>
      </DropDownItem>
      <DropDownItem
        className={'item wide ' + dropDownActiveClass(blockType === 'code')}
        onClick={() => formatCode(editor, blockType)}>
        <div className="icon-text-container">
          <i className="icon code" />
          <span className="text">Code Block</span>
        </div>
        <span className="shortcut">{shortcut('CODE_BLOCK')}</span>
      </DropDownItem>
    </DropDown>
  );
}

function Divider(): JSX.Element {
  return <div className="lexical-divider" />;
}

function IndentControls({
  editor,
  isRTL,
  disabled = false,
}: {
  editor: LexicalEditor;
  isRTL: boolean;
  disabled: boolean;
}) {
  return (
    <>
      <button
        aria-label="Outdent content"
        className="lexical-toolbar-item spaced"
        disabled={disabled}
        onClick={() => {
          editor.dispatchCommand(OUTDENT_CONTENT_COMMAND);
        }}
        title={`Outdent (${shortcut('OUTDENT')})`}
        type="button">
        <i className={'icon ' + (isRTL ? 'indent' : 'outdent')} />
      </button>
      <button
        aria-label="Indent content"
        className="lexical-toolbar-item"
        disabled={disabled}
        onClick={() => {
          editor.dispatchCommand(INDENT_CONTENT_COMMAND);
        }}
        title={`Indent (${shortcut('INDENT')})`}
        type="button">
        <i className={'icon ' + (isRTL ? 'outdent' : 'indent')} />
      </button>
    </>
  );
}

function $findTopLevelElement(node: LexicalNode) {
  let topLevelElement =
    node.getKey() === 'root'
      ? node
      : $findMatchingParent(node, e => {
          const parent = e.getParent();
          return parent !== null && $isRootOrShadowRoot(parent);
        });

  if (topLevelElement === null) {
    topLevelElement = node.getTopLevelElementOrThrow();
  }
  return topLevelElement;
}

export default function ToolbarPlugin({
  editor,
  activeEditor,
  setActiveEditor,
  setIsLinkEditMode,
}: {
  editor: LexicalEditor;
  activeEditor: LexicalEditor;
  setActiveEditor: Dispatch<LexicalEditor>;
  setIsLinkEditMode: Dispatch<boolean>;
}): JSX.Element {
  const {isLinkNode: isIntegrationLinkNode} = useEditorIntegration();
  const [selectedElementKey, setSelectedElementKey] = useState<NodeKey | null>(
    null,
  );
  const [modal, showModal] = useModal();
  const [isEditable, setIsEditable] = useState(() => editor.isEditable());
  const {toolbarState, updateToolbarState} = useToolbarState();
  const rovingRef = useLexicalRovingTabIndexRef();
  const focusManagerRef = useLexicalFocusManagerRef();
  const toolbarRef = useMergeRefs([rovingRef, focusManagerRef]);

  const dispatchToolbarCommand = <T extends AnyLexicalCommand>(
    command: T,
    payload: CommandPayloadType<T> | undefined = undefined,
    skipRefocus: boolean = false,
  ) => {
    activeEditor.update(() => {
      if (skipRefocus) {
        $addUpdateTag(SKIP_DOM_SELECTION_TAG);
      }

      // Re-assert on Type so that payload can have a default param
      activeEditor.dispatchCommand(command, payload as CommandPayloadType<T>);
    });
  };

  const dispatchFormatTextCommand = (
    payload: TextFormatType,
    skipRefocus: boolean = false,
  ) => dispatchToolbarCommand(FORMAT_TEXT_COMMAND, payload, skipRefocus);

  const $handleHeadingNode = useCallback(
    (selectedElement: LexicalNode) => {
      const type = $isHeadingNode(selectedElement)
        ? selectedElement.getTag()
        : selectedElement.getType();

      if (type in blockTypeToBlockName) {
        updateToolbarState(
          'blockType',
          type as keyof typeof blockTypeToBlockName,
        );
      }
    },
    [updateToolbarState],
  );

  const {
    settings: {isCodeHighlighted, isCodeShiki},
  } = useSettings();

  const $handleCodeNode = useCallback(
    (element: LexicalNode) => {
      if ($isCodeNode(element)) {
        const language = element.getLanguage();
        updateToolbarState(
          'codeLanguage',
          language
            ? (isCodeHighlighted &&
                (isCodeShiki
                  ? normalizeCodeLanguageShiki(language)
                  : normalizeCodeLanguagePrism(language))) ||
                language
            : '',
        );
        const theme = element.getTheme();
        updateToolbarState('codeTheme', theme || '');
        return;
      }
    },
    [updateToolbarState, isCodeHighlighted, isCodeShiki],
  );

  const $updateToolbar = useCallback(() => {
    const selection = $getSelection();
    if ($isRangeSelection(selection)) {
      if (activeEditor !== editor && $isEditorIsNestedEditor(activeEditor)) {
        const rootElement = activeEditor.getRootElement();
        updateToolbarState(
          'isImageCaption',
          !!rootElement?.parentElement?.classList.contains(
            'image-caption-container',
          ),
        );
      } else {
        updateToolbarState('isImageCaption', false);
      }

      const anchorNode = selection.anchor.getNode();
      const element = $findTopLevelElement(anchorNode);
      const elementKey = element.getKey();
      const elementDOM = activeEditor.getElementByKey(elementKey);

      updateToolbarState('isRTL', $isParentElementRTL(selection));

      // Update links
      const node = getSelectedNode(selection);
      const parent = node.getParent();
      const isLink = $isLinkNode(parent) || $isLinkNode(node);
      updateToolbarState('isLink', isLink);

      const tableNode = $findMatchingParent(node, $isTableNode);
      if ($isTableNode(tableNode)) {
        updateToolbarState('rootType', 'table');
      } else {
        updateToolbarState('rootType', 'root');
      }

      if (elementDOM !== null) {
        setSelectedElementKey(elementKey);
        if ($isListNode(element)) {
          const parentList = $getNearestNodeOfType(anchorNode, ListNode);
          const type = parentList
            ? parentList.getListType()
            : element.getListType();

          updateToolbarState('blockType', type);
        } else {
          $handleHeadingNode(element);
          $handleCodeNode(element);
        }
      }
    }
    if ($isRangeSelection(selection) || $isTableSelection(selection)) {
      // Update text format
      updateToolbarState('isBold', selection.hasFormat('bold'));
      updateToolbarState('isItalic', selection.hasFormat('italic'));
      updateToolbarState('isUnderline', selection.hasFormat('underline'));
      updateToolbarState(
        'isStrikethrough',
        selection.hasFormat('strikethrough'),
      );
      updateToolbarState('isSubscript', selection.hasFormat('subscript'));
      updateToolbarState('isSuperscript', selection.hasFormat('superscript'));
      updateToolbarState('isHighlight', selection.hasFormat('highlight'));
      updateToolbarState('isCode', selection.hasFormat('code'));
    }
    if ($isNodeSelection(selection)) {
      const nodes = selection.getNodes();
      for (const selectedNode of nodes) {
        const parentList = $getNearestNodeOfType(selectedNode, ListNode);
        if (parentList) {
          const type = parentList.getListType();
          updateToolbarState('blockType', type);
        } else {
          const selectedElement = $findTopLevelElement(selectedNode);
          $handleHeadingNode(selectedElement);
          $handleCodeNode(selectedElement);
        }
      }
    }
  }, [
    activeEditor,
    editor,
    updateToolbarState,
    $handleHeadingNode,
    $handleCodeNode,
  ]);

  useEffect(() => {
    return editor.registerCommand(
      SELECTION_CHANGE_COMMAND,
      (_payload, newEditor) => {
        setActiveEditor(newEditor);
        $onUpdate(() => newEditor.read('latest', $updateToolbar));
        return false;
      },
      COMMAND_PRIORITY_CRITICAL,
    );
  }, [editor, $updateToolbar, setActiveEditor]);

  useEffect(() => {
    activeEditor.read('latest', () => {
      $updateToolbar();
    });
  }, [activeEditor, $updateToolbar]);

  useEffect(() => {
    return mergeRegister(
      editor.registerEditableListener(editable => {
        setIsEditable(editable);
      }),
      activeEditor.registerUpdateListener(({editorState}) => {
        editorState.read(
          () => {
            $updateToolbar();
          },
          {editor: activeEditor},
        );
      }),
      activeEditor.registerCommand(
        CAN_UNDO_COMMAND,
        payload => {
          updateToolbarState('canUndo', payload);
          return false;
        },
        COMMAND_PRIORITY_CRITICAL,
      ),
      activeEditor.registerCommand(
        CAN_REDO_COMMAND,
        payload => {
          updateToolbarState('canRedo', payload);
          return false;
        },
        COMMAND_PRIORITY_CRITICAL,
      ),
    );
  }, [$updateToolbar, activeEditor, editor, updateToolbarState]);

  const insertLink = useCallback(() => {
    const isIntegrationLink = activeEditor.read('latest', () => {
      const selection = $getSelection();
      return (
        $isNodeSelection(selection) &&
        selection.getNodes().some(isIntegrationLinkNode)
      );
    });

    if (isIntegrationLink) {
      setIsLinkEditMode(true);
      return;
    }

    if (!toolbarState.isLink) {
      setIsLinkEditMode(true);
    } else {
      setIsLinkEditMode(false);
      activeEditor.dispatchCommand(TOGGLE_LINK_COMMAND, null);
    }
  }, [
    activeEditor,
    isIntegrationLinkNode,
    setIsLinkEditMode,
    toolbarState.isLink,
  ]);

  const onCodeLanguageSelect = useCallback(
    (value: string | null) => {
      activeEditor.update(() => {
        $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
        if (selectedElementKey !== null) {
          const node = $getNodeByKey(selectedElementKey);
          if ($isCodeNode(node)) {
            node.setLanguage(value);
          }
        }
      });
    },
    [activeEditor, selectedElementKey],
  );
  const onCodeThemeSelect = useCallback(
    (value: string) => {
      activeEditor.update(() => {
        if (selectedElementKey !== null) {
          const node = $getNodeByKey(selectedElementKey);
          if ($isCodeNode(node)) {
            node.setTheme(value);
          }
        }
      });
    },
    [activeEditor, selectedElementKey],
  );
  const insertGifOnClick = (payload: InsertImagePayload) => {
    activeEditor.dispatchCommand(INSERT_IMAGE_COMMAND, payload);
  };

  const canViewerSeeInsertDropdown = !toolbarState.isImageCaption;
  const canViewerSeeInsertCodeButton = !toolbarState.isImageCaption;

  return (
    <div
      ref={toolbarRef}
      className="lexical-toolbar"
      role="toolbar"
      aria-label="Editor toolbar">
      <button
        disabled={!toolbarState.canUndo || !isEditable}
        onClick={e =>
          dispatchToolbarCommand(UNDO_COMMAND, undefined, isKeyboardInput(e))
        }
        title={IS_APPLE ? 'Undo (⌘Z)' : 'Undo (Ctrl+Z)'}
        type="button"
        className="lexical-toolbar-item spaced"
        aria-label="Undo">
        <i className="format undo" />
      </button>
      <button
        disabled={!toolbarState.canRedo || !isEditable}
        onClick={e =>
          dispatchToolbarCommand(REDO_COMMAND, undefined, isKeyboardInput(e))
        }
        title={IS_APPLE ? 'Redo (⇧⌘Z)' : 'Redo (Ctrl+Y)'}
        type="button"
        className="lexical-toolbar-item"
        aria-label="Redo">
        <i className="format redo" />
      </button>
      <Divider />
      {toolbarState.blockType in blockTypeToBlockName &&
        activeEditor === editor && (
          <>
            <BlockFormatDropDown
              disabled={!isEditable}
              blockType={toolbarState.blockType}
              rootType={toolbarState.rootType}
              editor={activeEditor}
            />
            <Divider />
          </>
        )}
      {toolbarState.blockType === 'code' && isCodeHighlighted ? (
        <>
          {!isCodeShiki && (
            <DropDown
              disabled={!isEditable}
              buttonClassName="lexical-toolbar-item code-language"
              buttonLabel={
                toolbarState.codeLanguage
                  ? (CODE_LANGUAGE_OPTIONS_PRISM.find(
                      opt =>
                        opt[0] ===
                        normalizeCodeLanguagePrism(toolbarState.codeLanguage),
                    ) || ['', ''])[1]
                  : '(No language)'
              }
              buttonAriaLabel="Select language">
              <DropDownItem
                className={`item ${dropDownActiveClass(
                  !toolbarState.codeLanguage,
                )}`}
                onClick={() => onCodeLanguageSelect(null)}
                key="__no_language__">
                <span className="text">(No language)</span>
              </DropDownItem>
              {CODE_LANGUAGE_OPTIONS_PRISM.map(([value, name]) => {
                return (
                  <DropDownItem
                    className={`item ${dropDownActiveClass(
                      value === toolbarState.codeLanguage,
                    )}`}
                    onClick={() => onCodeLanguageSelect(value)}
                    key={value}>
                    <span className="text">{name}</span>
                  </DropDownItem>
                );
              })}
            </DropDown>
          )}
          {isCodeShiki && (
            <>
              <DropDown
                disabled={!isEditable}
                buttonClassName="lexical-toolbar-item code-language"
                buttonLabel={
                  toolbarState.codeLanguage
                    ? (CODE_LANGUAGE_OPTIONS_SHIKI.find(
                        opt =>
                          opt[0] ===
                          normalizeCodeLanguageShiki(toolbarState.codeLanguage),
                      ) || ['', ''])[1]
                    : '(No language)'
                }
                buttonAriaLabel="Select language">
                <DropDownItem
                  className={`item ${dropDownActiveClass(
                    !toolbarState.codeLanguage,
                  )}`}
                  onClick={() => onCodeLanguageSelect(null)}
                  key="__no_language__">
                  <span className="text">(No language)</span>
                </DropDownItem>
                {CODE_LANGUAGE_OPTIONS_SHIKI.map(([value, name]) => {
                  return (
                    <DropDownItem
                      className={`item ${dropDownActiveClass(
                        value === toolbarState.codeLanguage,
                      )}`}
                      onClick={() => onCodeLanguageSelect(value)}
                      key={value}>
                      <span className="text">{name}</span>
                    </DropDownItem>
                  );
                })}
              </DropDown>
              <DropDown
                disabled={!isEditable}
                buttonClassName="lexical-toolbar-item code-language"
                buttonLabel={
                  (CODE_THEME_OPTIONS_SHIKI.find(
                    opt => opt[0] === toolbarState.codeTheme,
                  ) || ['', ''])[1]
                }
                buttonAriaLabel="Select theme">
                {CODE_THEME_OPTIONS_SHIKI.map(([value, name]) => {
                  return (
                    <DropDownItem
                      className={`item ${dropDownActiveClass(
                        value === toolbarState.codeTheme,
                      )}`}
                      onClick={() => onCodeThemeSelect(value)}
                      key={value}>
                      <span className="text">{name}</span>
                    </DropDownItem>
                  );
                })}
              </DropDown>
            </>
          )}
        </>
      ) : (
        <>
          <button
            disabled={!isEditable}
            onClick={e => dispatchFormatTextCommand('bold', isKeyboardInput(e))}
            className={
              'lexical-toolbar-item spaced ' +
              (toolbarState.isBold ? 'active' : '')
            }
            title={`Bold (${shortcut('BOLD')})`}
            type="button"
            aria-label={`Format text as bold. Shortcut: ${shortcut('BOLD')}`}>
            <i className="format bold" />
          </button>
          <button
            disabled={!isEditable}
            onClick={e =>
              dispatchFormatTextCommand('italic', isKeyboardInput(e))
            }
            className={
              'lexical-toolbar-item spaced ' +
              (toolbarState.isItalic ? 'active' : '')
            }
            title={`Italic (${shortcut('ITALIC')})`}
            type="button"
            aria-label={`Format text as italics. Shortcut: ${shortcut('ITALIC')}`}>
            <i className="format italic" />
          </button>
          <button
            disabled={!isEditable}
            onClick={e =>
              dispatchFormatTextCommand('underline', isKeyboardInput(e))
            }
            className={
              'lexical-toolbar-item spaced ' +
              (toolbarState.isUnderline ? 'active' : '')
            }
            title={`Underline (${shortcut('UNDERLINE')})`}
            type="button"
            aria-label={`Format text to underlined. Shortcut: ${shortcut('UNDERLINE')}`}>
            <i className="format underline" />
          </button>
          {canViewerSeeInsertCodeButton && (
            <button
              disabled={!isEditable}
              onClick={e =>
                dispatchFormatTextCommand('code', isKeyboardInput(e))
              }
              className={
                'lexical-toolbar-item spaced ' +
                (toolbarState.isCode ? 'active' : '')
              }
              title={`Code (${shortcut('INSERT_CODE_BLOCK')})`}
              type="button"
              aria-label="Code">
              <i className="format code" />
            </button>
          )}
          <button
            disabled={!isEditable}
            onClick={insertLink}
            className={
              'lexical-toolbar-item spaced ' +
              (toolbarState.isLink ? 'active' : '')
            }
            aria-label="Insert link"
            title={`Insert link (${shortcut('INSERT_LINK')})`}
            type="button">
            <i className="format link-icon" />
          </button>
          <DropDown
            disabled={!isEditable}
            buttonClassName="lexical-toolbar-item spaced"
            buttonLabel=""
            buttonAriaLabel="Formatting options for additional text styles"
            buttonIconClassName="icon dropdown-more">
            <DropDownItem
              onClick={e =>
                dispatchFormatTextCommand('strikethrough', isKeyboardInput(e))
              }
              className={
                'item wide ' + dropDownActiveClass(toolbarState.isStrikethrough)
              }
              title="Strikethrough"
              aria-label="Format text with a strikethrough">
              <div className="icon-text-container">
                <i className="icon strikethrough" />
                <span className="text">Strikethrough</span>
              </div>
              <span className="shortcut">{shortcut('STRIKETHROUGH')}</span>
            </DropDownItem>
            <DropDownItem
              onClick={e =>
                dispatchFormatTextCommand('subscript', isKeyboardInput(e))
              }
              className={
                'item wide ' + dropDownActiveClass(toolbarState.isSubscript)
              }
              title="Subscript"
              aria-label="Format text with a subscript">
              <div className="icon-text-container">
                <i className="icon subscript" />
                <span className="text">Subscript</span>
              </div>
              <span className="shortcut">{shortcut('SUBSCRIPT')}</span>
            </DropDownItem>
            <DropDownItem
              onClick={e =>
                dispatchFormatTextCommand('superscript', isKeyboardInput(e))
              }
              className={
                'item wide ' + dropDownActiveClass(toolbarState.isSuperscript)
              }
              title="Superscript"
              aria-label="Format text with a superscript">
              <div className="icon-text-container">
                <i className="icon superscript" />
                <span className="text">Superscript</span>
              </div>
              <span className="shortcut">{shortcut('SUPERSCRIPT')}</span>
            </DropDownItem>
            <DropDownItem
              onClick={e =>
                dispatchFormatTextCommand('highlight', isKeyboardInput(e))
              }
              className={
                'item wide ' + dropDownActiveClass(toolbarState.isHighlight)
              }
              title="Highlight"
              aria-label="Format text with a highlight">
              <div className="icon-text-container">
                <i className="icon highlight" />
                <span className="text">Highlight</span>
              </div>
            </DropDownItem>
            <DropDownItem
              onClick={e => clearFormatting(activeEditor, isKeyboardInput(e))}
              className="item wide"
              title="Clear text formatting"
              aria-label="Clear all text formatting">
              <div className="icon-text-container">
                <i className="icon clear" />
                <span className="text">Clear Formatting</span>
              </div>
              <span className="shortcut">{shortcut('CLEAR_FORMATTING')}</span>
            </DropDownItem>
          </DropDown>
          {canViewerSeeInsertDropdown && (
            <>
              <Divider />
              <DropDown
                disabled={!isEditable}
                buttonClassName="lexical-toolbar-item spaced"
                buttonLabel="Insert"
                buttonAriaLabel="Insert specialized editor node"
                buttonIconClassName="icon plus">
                <DropDownItem
                  onClick={() =>
                    dispatchToolbarCommand(INSERT_HORIZONTAL_RULE_COMMAND)
                  }
                  className="item">
                  <i className="icon horizontal-rule" />
                  <span className="text">Horizontal Rule</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() => {
                    showModal('Insert Image', onClose => (
                      <InsertImageDialog
                        activeEditor={activeEditor}
                        onClose={onClose}
                      />
                    ));
                  }}
                  className="item">
                  <i className="icon image" />
                  <span className="text">Image</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() =>
                    insertGifOnClick({
                      altText: 'Cat typing on a laptop',
                      src: catTypingGif,
                    })
                  }
                  className="item">
                  <i className="icon gif" />
                  <span className="text">GIF</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() =>
                    dispatchToolbarCommand(INSERT_EXCALIDRAW_COMMAND)
                  }
                  className="item">
                  <i className="icon diagram-2" />
                  <span className="text">Excalidraw</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() => {
                    showModal('Insert Table', onClose => (
                      <InsertTableDialog
                        activeEditor={activeEditor}
                        onClose={onClose}
                      />
                    ));
                  }}
                  className="item">
                  <i className="icon table-icon" />
                  <span className="text">Table</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() => {
                    showModal('Insert Poll', onClose => (
                      <InsertPollDialog
                        activeEditor={activeEditor}
                        onClose={onClose}
                      />
                    ));
                  }}
                  className="item">
                  <i className="icon poll" />
                  <span className="text">Poll</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() => {
                    showModal('Insert Columns Layout', onClose => (
                      <InsertLayoutDialog
                        activeEditor={activeEditor}
                        onClose={onClose}
                      />
                    ));
                  }}
                  className="item">
                  <i className="icon columns" />
                  <span className="text">Columns Layout</span>
                </DropDownItem>

                <DropDownItem
                  onClick={() => {
                    showModal('Insert Equation', onClose => (
                      <InsertEquationDialog
                        activeEditor={activeEditor}
                        onClose={onClose}
                      />
                    ));
                  }}
                  className="item">
                  <i className="icon equation" />
                  <span className="text">Equation</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() => {
                    editor.update(() => {
                      $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
                      const root = $getRoot();
                      const stickyNode = $createStickyNode(0, 0);
                      root.append(stickyNode);
                    });
                  }}
                  className="item">
                  <i className="icon sticky" />
                  <span className="text">Sticky Note</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() =>
                    dispatchToolbarCommand(INSERT_COLLAPSIBLE_COMMAND)
                  }
                  className="item">
                  <i className="icon caret-right" />
                  <span className="text">Collapsible container</span>
                </DropDownItem>
                <DropDownItem
                  onClick={() => {
                    const dateTime = new Date();
                    dateTime.setHours(0, 0, 0, 0);
                    dispatchToolbarCommand(INSERT_DATETIME_COMMAND, {
                      dateTime,
                    });
                  }}
                  className="item">
                  <i className="icon calendar" />
                  <span className="text">Date</span>
                </DropDownItem>
                {EmbedConfigs.map(embedConfig => (
                  <DropDownItem
                    key={embedConfig.type}
                    onClick={() =>
                      dispatchToolbarCommand(
                        INSERT_EMBED_COMMAND,
                        embedConfig.type,
                      )
                    }
                    className="item">
                    {embedConfig.icon}
                    <span className="text">{embedConfig.contentName}</span>
                  </DropDownItem>
                ))}
              </DropDown>
            </>
          )}
        </>
      )}
      <Divider />
      <IndentControls
        disabled={!isEditable}
        editor={activeEditor}
        isRTL={toolbarState.isRTL}
      />

      {modal}
    </div>
  );
}
