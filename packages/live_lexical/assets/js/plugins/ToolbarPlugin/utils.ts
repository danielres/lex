/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */
import {$createCodeNode} from '@lexical/code';
import {
  INSERT_CHECK_LIST_COMMAND,
  INSERT_ORDERED_LIST_COMMAND,
  INSERT_UNORDERED_LIST_COMMAND,
} from '@lexical/list';
import {$isDecoratorBlockNode} from '@lexical/react/LexicalDecoratorBlockNode';
import {
  $createHeadingNode,
  $createQuoteNode,
  $isHeadingNode,
  $isQuoteNode,
  type HeadingTagType,
} from '@lexical/rich-text';
import {$patchStyleText, $setBlocksType} from '@lexical/selection';
import {$isTableSelection} from '@lexical/table';
import {$getNearestBlockElementAncestorOrThrow} from '@lexical/utils';
import {
  $addUpdateTag,
  $createParagraphNode,
  $createRangeSelection,
  $findMatchingParent,
  $getEditor,
  $getSelection,
  $isBlockElementNode,
  $isBlockFullySelected,
  $isLineBreakNode,
  $isRangeSelection,
  $isTextNode,
  $setSelection,
  $splitNode,
  type ElementNode,
  type LexicalEditor,
  type LexicalNode,
  type NodeKey,
  type RangeSelection,
  SKIP_DOM_SELECTION_TAG,
  SKIP_SELECTION_FOCUS_TAG,
} from 'lexical';

export const $formatParagraph = () => {
  $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
  const selection = $getSelection();
  $setBlocksType(selection, () => $createParagraphNode());
};

export const formatParagraph = (editor: LexicalEditor) => {
  editor.update(() => $formatParagraph());
};

export const $formatHeading = (
  blockType: string,
  headingSize: HeadingTagType,
) => {
  if (blockType !== headingSize) {
    $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
    const selection = $getSelection();
    $setBlocksType(selection, () => $createHeadingNode(headingSize));
    const updatedSelection = $getSelection();
    if (updatedSelection) {
      $patchStyleText(updatedSelection, {'font-size': null});
    }
  }
};

export const formatHeading = (
  editor: LexicalEditor,
  blockType: string,
  headingSize: HeadingTagType,
) => {
  editor.update(() => $formatHeading(blockType, headingSize));
};

export const $formatBulletList = (blockType: string) => {
  if (blockType !== 'bullet') {
    $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
    $getEditor().dispatchCommand(INSERT_UNORDERED_LIST_COMMAND);
  } else {
    $formatParagraph();
  }
};

export const formatBulletList = (editor: LexicalEditor, blockType: string) => {
  editor.update(() => $formatBulletList(blockType));
};

export const $formatCheckList = (blockType: string) => {
  if (blockType !== 'check') {
    $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
    $getEditor().dispatchCommand(INSERT_CHECK_LIST_COMMAND);
  } else {
    $formatParagraph();
  }
};

export const formatCheckList = (editor: LexicalEditor, blockType: string) => {
  editor.update(() => $formatCheckList(blockType));
};

export const $formatNumberedList = (blockType: string) => {
  if (blockType !== 'number') {
    $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
    $getEditor().dispatchCommand(INSERT_ORDERED_LIST_COMMAND);
  } else {
    $formatParagraph();
  }
};

export const formatNumberedList = (
  editor: LexicalEditor,
  blockType: string,
) => {
  editor.update(() => $formatNumberedList(blockType));
};

export const $formatQuote = (blockType: string) => {
  if (blockType !== 'quote') {
    $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
    const selection = $getSelection();
    $setBlocksType(selection, () => $createQuoteNode());
  }
};

export const formatQuote = (editor: LexicalEditor, blockType: string) => {
  editor.update(() => $formatQuote(blockType));
};

function $splitBlocksByLineBreaks(selection: RangeSelection): void {
  const blocks: Set<ElementNode> = new Set();
  for (const node of selection.getNodes()) {
    const block = $findBlockAncestor(node);
    if (block !== null) {
      blocks.add(block);
    }
  }
  for (const point of [selection.anchor, selection.focus]) {
    const block = $findBlockAncestor(point.getNode());
    if (block !== null) {
      blocks.add(block);
    }
  }

  const anchorKey = selection.anchor.key;
  const anchorOffset = selection.anchor.offset;
  const anchorType = selection.anchor.type;
  const focusKey = selection.focus.key;
  const focusOffset = selection.focus.offset;
  const focusType = selection.focus.type;

  for (const block of blocks) {
    const children = block.getChildren();
    const lbIndices: number[] = [];
    for (let i = 0; i < children.length; i++) {
      if ($isLineBreakNode(children[i])) {
        lbIndices.push(i);
      }
    }
    if (lbIndices.length === 0) {
      continue;
    }
    for (let j = lbIndices.length - 1; j >= 0; j--) {
      const [, rightBlock] = $splitNode(block, lbIndices[j]);
      const firstChild = rightBlock.getFirstChild();
      if ($isLineBreakNode(firstChild)) {
        firstChild.remove();
      }
    }
  }

  const newSelection = $createRangeSelection();
  newSelection.anchor.set(anchorKey, anchorOffset, anchorType);
  newSelection.focus.set(focusKey, focusOffset, focusType);
  $setSelection(newSelection);
}

function $findBlockAncestor(node: LexicalNode): ElementNode | null {
  return $findMatchingParent(node, $isBlockElementNode);
}

export const $formatCode = (blockType: string) => {
  if (blockType !== 'code') {
    $addUpdateTag(SKIP_SELECTION_FOCUS_TAG);
    let selection = $getSelection();
    if (!selection) {
      return;
    }
    if (!$isRangeSelection(selection) || selection.isCollapsed()) {
      $setBlocksType(selection, () => $createCodeNode());
    } else {
      // Each LineBreakNode becomes a block boundary so insertNodes below
      // can place the code block on its own row, not between <br>s.
      $splitBlocksByLineBreaks(selection);
      selection = $getSelection();
      if (!$isRangeSelection(selection)) {
        return;
      }
      const textContent = selection.getTextContent();
      // The trailing paragraph absorbs the post-insertion merge that
      // would otherwise fold the original block's trailing content into
      // the code node.
      const codeNode = $createCodeNode();
      const trailingParagraph = $createParagraphNode();
      selection.insertNodes([codeNode, trailingParagraph]);
      // insertNodes leaves the cursor in the trailing paragraph.
      selection = codeNode.select();
      selection.insertRawText(textContent);
      // Drop the trailing paragraph if the merge step didn't fill it.
      if (trailingParagraph.isAttached() && trailingParagraph.isEmpty()) {
        trailingParagraph.remove();
      }
    }
  }
};

export const formatCode = (editor: LexicalEditor, blockType: string) => {
  editor.update(() => $formatCode(blockType));
};

function $clearBlockFormat(block: ElementNode): void {
  if (block.getFormat() !== 0) {
    block.setFormat('');
  }
  if (block.getIndent() !== 0) {
    block.setIndent(0);
  }
}

export const $clearFormatting = (skipRefocus: boolean = false) => {
  if (skipRefocus) {
    $addUpdateTag(SKIP_DOM_SELECTION_TAG);
  }
  const selection = $getSelection();
  if ($isRangeSelection(selection) || $isTableSelection(selection)) {
    const anchor = selection.anchor;
    const focus = selection.focus;
    const extractedNodes = selection.extract();

    if (anchor.key === focus.key && anchor.offset === focus.offset) {
      $clearBlockFormat(
        $getNearestBlockElementAncestorOrThrow(anchor.getNode()),
      );
      return;
    }

    // Determine which blocks are fully selected before making any
    // changes, since the mutations below (such as replacing a
    // HeadingNode with a ParagraphNode) would detach nodes that the
    // selection's carets may refer to
    const postExtractSelection = $getSelection();
    let fullySelectedBlocks: null | Set<NodeKey> = null;
    if ($isRangeSelection(postExtractSelection)) {
      fullySelectedBlocks = new Set();
      for (const node of extractedNodes) {
        if ($isTextNode(node)) {
          const block = $getNearestBlockElementAncestorOrThrow(node);
          if (
            !fullySelectedBlocks.has(block.getKey()) &&
            $isBlockFullySelected(block, postExtractSelection)
          ) {
            fullySelectedBlocks.add(block.getKey());
          }
        }
      }
    }

    extractedNodes.forEach(node => {
      if ($isTextNode(node)) {
        if (node.getStyle() !== '') {
          node.setStyle('');
        }
        if (node.getFormat() !== 0) {
          node.setFormat(0);
        }
        const nearestBlockElement =
          $getNearestBlockElementAncestorOrThrow(node);
        if (
          fullySelectedBlocks === null ||
          fullySelectedBlocks.has(nearestBlockElement.getKey())
        ) {
          $clearBlockFormat(nearestBlockElement);
        }
      } else if ($isHeadingNode(node) || $isQuoteNode(node)) {
        node.replace($createParagraphNode(), true);
      } else if ($isDecoratorBlockNode(node)) {
        node.setFormat('');
      }
    });

    // hasFormat() reads the format cached on the RangeSelection rather than
    // the nodes, so the toolbars would keep showing the cleared formats as
    // active (#8881)
    const clearedSelection = $getSelection();
    if ($isRangeSelection(clearedSelection)) {
      clearedSelection.setFormat(0);
      clearedSelection.setStyle('');
    }
  }
};

export const clearFormatting = (
  editor: LexicalEditor,
  skipRefocus: boolean = false,
) => {
  editor.update(() => $clearFormatting(skipRefocus));
};
