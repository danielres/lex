/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import type {JSX} from 'react';

import {
  $applyNodeReplacement,
  $getDocument,
  booleanValue,
  DecoratorNode,
  type DOMExportOutput,
  type EditorConfig,
  type LexicalNode,
  type NodeKey,
  nodeSchema,
  numberValue,
  optional,
  type SerializedLexicalNode,
  type Spread,
  stringValue,
  withAccessors,
  withField,
} from 'lexical';
import * as React from 'react';

const ImageComponent = React.lazy(() => import('./ImageComponent'));

export interface ImagePayload {
  altText: string;
  caption?: string;
  height?: number;
  key?: NodeKey;
  maxWidth?: number;
  showCaption?: boolean;
  src: string;
  width?: number;
  captionsEnabled?: boolean;
}

export type SerializedImageNode = Spread<
  {
    altText: string;
    caption: string;
    height?: number;
    maxWidth: number;
    showCaption: boolean;
    src: string;
    width?: number;
  },
  SerializedLexicalNode
>;

const imageNodeSchema = nodeSchema<ImageNode>()({
  altText: stringValue(),
  caption: withField(stringValue(), {field: '__caption'}),
  // An unsized dimension is the 'inherit' sentinel, which has always
  // serialized as 0 (and parses back through `|| 'inherit'`).
  height: withAccessors(optional(numberValue()), {
    getter: 'getSerializedHeight',
  }),
  // Read straight from the field, but applied through setMaxWidth: an absent
  // `maxWidth` parses to `undefined`, and the setter reads that as "keep the
  // constructor's default" rather than as a value to store.
  maxWidth: withAccessors(optional(numberValue()), {
    getter: {field: '__maxWidth'},
  }),
  showCaption: withField(booleanValue(), {field: '__showCaption'}),
  src: stringValue(),
  width: withAccessors(optional(numberValue()), {
    getter: 'getSerializedWidth',
  }),
});

export class ImageNode extends DecoratorNode<JSX.Element> {
  __src: string;
  __altText: string;
  __width: 'inherit' | number;
  __height: 'inherit' | number;
  __maxWidth: number;
  __showCaption: boolean;
  __caption: string;
  // Captions cannot yet be used within editor cells
  __captionsEnabled: boolean;

  $config() {
    return this.config('image', {
      extends: DecoratorNode,
      json: imageNodeSchema,
    });
  }

  static clone(node: ImageNode): ImageNode {
    return new ImageNode(
      node.__src,
      node.__altText,
      node.__maxWidth,
      node.__width,
      node.__height,
      node.__showCaption,
      node.__caption,
      node.__captionsEnabled,
      node.__key,
    );
  }

  getCaption(): string {
    return this.getLatest().__caption;
  }

  getTextContent(): string {
    const latest = this.getLatest();
    return latest.__showCaption ? latest.__caption : '';
  }

  /** @internal 'inherit' has always serialized as 0. */
  getSerializedWidth(): number {
    const width = this.getLatest().__width;
    return width === 'inherit' ? 0 : width;
  }

  /** @internal */
  getSerializedHeight(): number {
    const height = this.getLatest().__height;
    return height === 'inherit' ? 0 : height;
  }

  setCaption(caption: string): this {
    const self = this.getWritable();
    self.__caption = caption;
    return self;
  }

  exportDOM(): DOMExportOutput {
    const imgElement = $getDocument().createElement('img');
    imgElement.setAttribute('src', this.__src);
    imgElement.setAttribute('alt', this.__altText);
    imgElement.setAttribute('width', this.__width.toString());
    imgElement.setAttribute('height', this.__height.toString());

    if (this.__showCaption && this.__caption.trim() !== '') {
      const figureElement = $getDocument().createElement('figure');
      const figcaptionElement = $getDocument().createElement('figcaption');
      figcaptionElement.textContent = this.__caption;

      figureElement.appendChild(imgElement);
      figureElement.appendChild(figcaptionElement);

      return {element: figureElement};
    }

    return {element: imgElement};
  }

  setSrc(src: string): this {
    const self = this.getWritable();
    self.__src = src;
    return self;
  }

  setAltText(altText: string): this {
    const self = this.getWritable();
    self.__altText = altText;
    return self;
  }

  setMaxWidth(maxWidth: number | undefined): this {
    const self = this.getWritable();
    self.__maxWidth = maxWidth === undefined ? self.__maxWidth : maxWidth;
    return self;
  }

  // `width`/`height` are absent from the JSON when the image is unsized, which
  // is stored as the sentinel 'inherit'.
  // An unsized image serializes as 0 (and older documents may omit the
  // property), both of which restore the 'inherit' sentinel — the same
  // mapping the constructor's `width || 'inherit'` has always applied.
  setWidth(width: number | undefined): this {
    const self = this.getWritable();
    self.__width = width || 'inherit';
    return self;
  }

  setHeight(height: number | undefined): this {
    const self = this.getWritable();
    self.__height = height || 'inherit';
    return self;
  }

  constructor(
    src: string = '',
    altText: string = '',
    maxWidth: number = 500,
    width?: 'inherit' | number,
    height?: 'inherit' | number,
    showCaption?: boolean,
    caption: string = '',
    captionsEnabled?: boolean,
    key?: NodeKey,
  ) {
    super(key);
    this.__src = src;
    this.__altText = altText;
    this.__maxWidth = maxWidth;
    this.__width = width || 'inherit';
    this.__height = height || 'inherit';
    this.__showCaption = showCaption || false;
    this.__caption = caption;
    this.__captionsEnabled = captionsEnabled !== false;
  }

  setWidthAndHeight(
    width: 'inherit' | number,
    height: 'inherit' | number,
  ): this {
    const writable = this.getWritable();
    writable.__width = width;
    writable.__height = height;
    return writable;
  }

  setShowCaption(showCaption: boolean): this {
    const writable = this.getWritable();
    writable.__showCaption = showCaption;
    return writable;
  }

  // View

  createDOM(config: EditorConfig): HTMLElement {
    const span = $getDocument().createElement('span');
    const theme = config.theme;
    const className = theme.image;
    if (className !== undefined) {
      span.className = className;
    }
    return span;
  }

  updateDOM(): false {
    return false;
  }

  getSrc(): string {
    return this.getLatest().__src;
  }

  getAltText(): string {
    return this.getLatest().__altText;
  }

  decorate(): JSX.Element {
    return (
      <ImageComponent
        src={this.__src}
        altText={this.__altText}
        width={this.__width}
        height={this.__height}
        maxWidth={this.__maxWidth}
        nodeKey={this.getKey()}
        showCaption={this.__showCaption}
        caption={this.__caption}
        captionsEnabled={this.__captionsEnabled}
        resizable={true}
      />
    );
  }
}

export function $createImageNode({
  altText,
  height,
  maxWidth = 500,
  captionsEnabled,
  src,
  width,
  showCaption,
  caption,
  key,
}: ImagePayload): ImageNode {
  return $applyNodeReplacement(
    new ImageNode(
      src,
      altText,
      maxWidth,
      width,
      height,
      showCaption,
      caption,
      captionsEnabled,
      key,
    ),
  );
}

export function $isImageNode(
  node: LexicalNode | null | undefined,
): node is ImageNode {
  return node instanceof ImageNode;
}
