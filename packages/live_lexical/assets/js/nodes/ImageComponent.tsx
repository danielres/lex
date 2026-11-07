/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import {useLexicalComposerContext} from '@lexical/react/LexicalComposerContext';
import {useLexicalEditable} from '@lexical/react/useLexicalEditable';
import {useLexicalNodeSelection} from '@lexical/react/useLexicalNodeSelection';
import {
  $getNodeByKey,
  $getSelection,
  $isNodeSelection,
  $isRangeSelection,
  $setSelection,
  CLICK_COMMAND,
  COMMAND_PRIORITY_LOW,
  createCommand,
  DRAGSTART_COMMAND,
  getActiveElement,
  KEY_ENTER_COMMAND,
  KEY_ESCAPE_COMMAND,
  type LexicalCommand,
  mergeRegister,
  type NodeKey,
  registerEventListener,
} from 'lexical';
import * as React from 'react';
import {
  type JSX,
  Suspense,
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
} from 'react';

import brokenImage from '../images/image-broken.svg';
import ImageResizer from '../ui/ImageResizer';
import {$isImageNode} from './ImageNode';

type ImageStatus =
  {error: true} | {error: false; width: number; height: number};

const imageCache = new Map<string, Promise<ImageStatus> | ImageStatus>();

export const RIGHT_CLICK_IMAGE_COMMAND: LexicalCommand<MouseEvent> =
  createCommand('RIGHT_CLICK_IMAGE_COMMAND');

function useSuspenseImage(src: string): ImageStatus {
  let cached = imageCache.get(src);
  if (cached && 'error' in cached && typeof cached.error === 'boolean') {
    return cached;
  } else if (!cached) {
    cached = new Promise<ImageStatus>(resolve => {
      const img = new Image();
      img.src = src;
      img.onload = () =>
        resolve({
          error: false,
          height: img.naturalHeight,
          width: img.naturalWidth,
        });
      img.onerror = () => resolve({error: true});
    }).then(rval => {
      imageCache.set(src, rval);
      return rval;
    });
    imageCache.set(src, cached);
    throw cached;
  }
  throw cached;
}

function isSVG(src: string): boolean {
  const lowerCaseSrc = src.toLowerCase();
  return (
    lowerCaseSrc.endsWith('.svg') ||
    lowerCaseSrc.startsWith('data:image/svg+xml')
  );
}

function LazyImage({
  altText,
  className,
  imageRef,
  src,
  width,
  height,
  maxWidth,
  onError,
}: {
  altText: string;
  className: string | null;
  height: 'inherit' | number;
  imageRef: {current: null | HTMLImageElement};
  maxWidth: number;
  src: string;
  width: 'inherit' | number;
  onError: () => void;
}): JSX.Element {
  const status = useSuspenseImage(src);

  useEffect(() => {
    if (status.error) {
      onError();
    }
  }, [status.error, onError]);

  if (status.error) {
    return <BrokenImage />;
  }

  // Calculate final dimensions with proper scaling
  const calculateDimensions = () => {
    if (width !== 'inherit' && height !== 'inherit') {
      return {
        height,
        maxWidth,
        width,
      };
    }

    const isActuallySVG = isSVG(src);

    // For standard images, Lexical expects 'inherit'
    if (!isActuallySVG) {
      return {
        height,
        maxWidth,
        width,
      };
    }

    // Use natural dimensions if available, otherwise fallback to defaults
    const naturalWidth = status.width;
    const naturalHeight = status.height;

    //  If SVG has no intrinsic dimensions (0), fallback to a sensible default (maxWidth)
    let finalWidth = naturalWidth || maxWidth;
    let finalHeight = naturalHeight || finalWidth;

    // Scale down if width exceeds maxWidth while maintaining aspect ratio
    if (finalWidth > maxWidth) {
      const scale = maxWidth / finalWidth;
      finalWidth = maxWidth;
      finalHeight = Math.round(finalHeight * scale);
    }

    // Scale down if height exceeds maxHeight while maintaining aspect ratio
    const maxHeight = 500;
    if (finalHeight > maxHeight) {
      const scale = maxHeight / finalHeight;
      finalHeight = maxHeight;
      finalWidth = Math.round(finalWidth * scale);
    }

    return {
      height: finalHeight,
      maxWidth,
      width: finalWidth,
    };
  };

  const imageStyle = calculateDimensions();

  return (
    <img
      className={className || undefined}
      src={src}
      alt={altText}
      ref={imageRef}
      style={imageStyle}
      onError={onError}
      draggable="false"
    />
  );
}

function BrokenImage(): JSX.Element {
  return (
    <img
      src={brokenImage}
      style={{
        height: 200,
        opacity: 0.2,
        width: 200,
      }}
      draggable="false"
      alt="Broken image"
    />
  );
}

export default function ImageComponent({
  src,
  altText,
  nodeKey,
  width,
  height,
  maxWidth,
  resizable,
  showCaption,
  caption,
  captionsEnabled,
}: {
  altText: string;
  caption: string;
  height: 'inherit' | number;
  maxWidth: number;
  nodeKey: NodeKey;
  resizable: boolean;
  showCaption: boolean;
  src: string;
  width: 'inherit' | number;
  captionsEnabled: boolean;
}): JSX.Element {
  const imageRef = useRef<null | HTMLImageElement>(null);
  const buttonRef = useRef<HTMLButtonElement | null>(null);
  const captionInputRef = useRef<HTMLInputElement | null>(null);
  const focusNewCaptionRef = useRef(false);
  const [isSelected, setSelected, clearSelection] =
    useLexicalNodeSelection(nodeKey);
  const [isResizing, setIsResizing] = useState<boolean>(false);
  const [editor] = useLexicalComposerContext();
  const [isLoadError, setIsLoadError] = useState<boolean>(false);
  const isEditable = useLexicalEditable();
  const isInNodeSelection = useMemo(
    () =>
      isSelected &&
      editor.read('latest', () => {
        const selection = $getSelection();
        return $isNodeSelection(selection) && selection.has(nodeKey);
      }),
    [editor, isSelected, nodeKey],
  );

  const $onEnter = useCallback(
    (event: KeyboardEvent | null) => {
      const latestSelection = $getSelection();
      const buttonElem = buttonRef.current;
      if (
        $isNodeSelection(latestSelection) &&
        latestSelection.has(nodeKey) &&
        latestSelection.getNodes().length === 1
      ) {
        if (showCaption) {
          $setSelection(null);
          if (event !== null) {
            event.preventDefault();
          }
          captionInputRef.current?.focus();
          return true;
        } else if (
          buttonElem !== null &&
          // getActiveElement rather than document.activeElement, which reports
          // the shadow host when the editor is in a shadow root.
          buttonElem !== getActiveElement(buttonElem)
        ) {
          if (event !== null) {
            event.preventDefault();
          }
          buttonElem.focus();
          return true;
        }
      }
      return false;
    },
    [nodeKey, showCaption],
  );

  const focusImage = useCallback(() => {
    editor.update(() => {
      $setSelection(null);
      setSelected(true);
      const parentRootElement = editor.getRootElement();
      if (parentRootElement !== null) {
        parentRootElement.focus();
      }
    });
  }, [editor, setSelected]);

  const $onEscape = useCallback(
    (event: KeyboardEvent) => {
      if (buttonRef.current === event.target) {
        focusImage();
        return true;
      }
      return false;
    },
    [focusImage],
  );

  const onClick = useCallback(
    (payload: MouseEvent) => {
      const event = payload;

      if (isResizing) {
        return true;
      }
      if (event.target === imageRef.current) {
        if (event.shiftKey) {
          setSelected(!isSelected);
        } else {
          clearSelection();
          setSelected(true);
        }
        return true;
      }

      return false;
    },
    [isResizing, isSelected, setSelected, clearSelection],
  );

  const onRightClick = useCallback(
    (event: MouseEvent): void => {
      editor.read('latest', () => {
        const latestSelection = $getSelection();
        const domElement = event.target as HTMLElement;
        if (
          domElement.tagName === 'IMG' &&
          $isRangeSelection(latestSelection) &&
          latestSelection.getNodes().length === 1
        ) {
          editor.dispatchCommand(RIGHT_CLICK_IMAGE_COMMAND, event);
        }
      });
    },
    [editor],
  );

  useEffect(() => {
    return mergeRegister(
      editor.registerCommand(
        DRAGSTART_COMMAND,
        event => {
          if (event.target === imageRef.current) {
            // TODO This is just a temporary workaround for FF to behave like other browsers.
            // Ideally, this handles drag & drop too (and all browsers).
            event.preventDefault();
            return true;
          }
          return false;
        },
        COMMAND_PRIORITY_LOW,
      ),
      editor.registerCommand(CLICK_COMMAND, onClick, COMMAND_PRIORITY_LOW),
      editor.registerCommand(
        RIGHT_CLICK_IMAGE_COMMAND,
        onClick,
        COMMAND_PRIORITY_LOW,
      ),
      editor.registerCommand(KEY_ENTER_COMMAND, $onEnter, COMMAND_PRIORITY_LOW),
      editor.registerCommand(
        KEY_ESCAPE_COMMAND,
        $onEscape,
        COMMAND_PRIORITY_LOW,
      ),
      editor.registerRootListener(rootElement => {
        if (rootElement) {
          return registerEventListener(
            rootElement,
            'contextmenu',
            onRightClick,
          );
        }
      }),
    );
  }, [editor, $onEnter, $onEscape, onClick, onRightClick]);

  const setShowCaption = (show: boolean) => {
    focusNewCaptionRef.current = show;
    editor.update(() => {
      const node = $getNodeByKey(nodeKey);
      if ($isImageNode(node)) {
        node.setShowCaption(show);
      }
    });
  };

  const setCaption = (nextCaption: string) => {
    editor.update(() => {
      const node = $getNodeByKey(nodeKey);
      if ($isImageNode(node)) {
        node.setCaption(nextCaption);
      }
    });
  };

  const hideEmptyCaption = (nextCaption: string) => {
    if (nextCaption.trim() !== '') {
      return;
    }

    editor.update(() => {
      const node = $getNodeByKey(nodeKey);
      if ($isImageNode(node)) {
        node.setCaption('');
        node.setShowCaption(false);
      }
    });
  };

  useEffect(() => {
    if (showCaption && focusNewCaptionRef.current) {
      focusNewCaptionRef.current = false;
      captionInputRef.current?.focus();
    }
  }, [showCaption]);

  const onResizeEnd = (
    nextWidth: 'inherit' | number,
    nextHeight: 'inherit' | number,
  ) => {
    // Delay hiding the resize bars for click case
    setTimeout(() => {
      setIsResizing(false);
    }, 200);

    editor.update(() => {
      const node = $getNodeByKey(nodeKey);
      if ($isImageNode(node)) {
        node.setWidthAndHeight(nextWidth, nextHeight);
      }
    });
  };

  const onResizeStart = () => {
    setIsResizing(true);
  };

  const draggable = isInNodeSelection && !isResizing;
  const isFocused = (isSelected || isResizing) && isEditable;
  return (
    <Suspense fallback={null}>
      <>
        <div draggable={draggable}>
          {isLoadError ? (
            <BrokenImage />
          ) : (
            <LazyImage
              className={
                isFocused
                  ? `focused ${isInNodeSelection ? 'draggable' : ''}`
                  : null
              }
              src={src}
              altText={altText}
              imageRef={imageRef}
              width={width}
              height={height}
              maxWidth={maxWidth}
              onError={() => setIsLoadError(true)}
            />
          )}
        </div>

        {showCaption && (isEditable || caption.trim() !== '') && (
          <div className="image-caption-container">
            {isEditable ? (
              <input
                ref={captionInputRef}
                aria-label="Image caption"
                className="image-caption-input"
                onBlur={event => hideEmptyCaption(event.currentTarget.value)}
                onChange={event => setCaption(event.currentTarget.value)}
                onKeyDown={event => {
                  event.stopPropagation();
                  if (event.key === 'Enter' || event.key === 'Escape') {
                    event.preventDefault();
                    focusImage();
                  }
                }}
                placeholder="Enter a caption..."
                type="text"
                value={caption}
              />
            ) : (
              <span className="image-caption-text">{caption}</span>
            )}
          </div>
        )}
        {resizable && isInNodeSelection && isFocused && (
          <ImageResizer
            showCaption={showCaption}
            setShowCaption={setShowCaption}
            editor={editor}
            buttonRef={buttonRef}
            imageRef={imageRef}
            maxWidth={maxWidth}
            onResizeStart={onResizeStart}
            onResizeEnd={onResizeEnd}
            captionsEnabled={!isLoadError && captionsEnabled}
          />
        )}
      </>
    </Suspense>
  );
}
