/**
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 */

import type {
  ExcalidrawElement,
  NonDeleted,
} from '@excalidraw/excalidraw/element/types';
import type {AppState, BinaryFiles} from '@excalidraw/excalidraw/types';

import {exportToSvg} from '@excalidraw/excalidraw';
import * as React from 'react';
import {type JSX, useEffect, useMemo, useState} from 'react';

type ImageType = 'svg' | 'canvas';

type Dimension = 'inherit' | number;

type Props = {
  /**
   * Configures the export setting for SVG/Canvas
   */
  appState: AppState;
  /**
   * The css class applied to image to be rendered
   */
  className?: string;
  /**
   * The Excalidraw elements to be rendered as an image
   */
  elements: NonDeleted<ExcalidrawElement>[];
  /**
   * The Excalidraw files associated with the elements
   */
  files: BinaryFiles;
  /**
   * The height of the image to be rendered
   */
  height?: Dimension;
  /**
   * The ref object to be used to render the image
   */
  imageContainerRef: React.RefObject<HTMLDivElement | null>;
  /**
   * The type of image to be rendered
   */
  imageType?: ImageType;
  /**
   * The css class applied to the root element of this component
   */
  rootClassName?: string | null;
  /**
   * The width of the image to be rendered
   */
  width?: Dimension;
};

// exportToSvg has fonts from excalidraw.com
// We don't want them to be used in open source
const removeStyleFromSvg_HACK = (svg: SVGElement) => {
  const styleTag = svg?.firstElementChild?.firstElementChild;

  // Generated SVG is getting double-sized by height and width attributes
  // We want to match the real size of the SVG element
  const viewBox = svg.getAttribute('viewBox');
  if (viewBox != null) {
    const viewBoxDimensions = viewBox.split(' ');
    svg.setAttribute('width', viewBoxDimensions[2]);
    svg.setAttribute('height', viewBoxDimensions[3]);
  }

  if (styleTag && styleTag.tagName === 'style') {
    styleTag.remove();
  }
};

function useAppDarkMode(): boolean {
  const [isDarkMode, setIsDarkMode] = useState(
    () => document.documentElement.dataset.theme === 'dark',
  );

  useEffect(() => {
    const root = document.documentElement;
    const updateTheme = () => setIsDarkMode(root.dataset.theme === 'dark');
    const observer = new MutationObserver(updateTheme);

    observer.observe(root, {
      attributeFilter: ['data-theme'],
      attributes: true,
    });

    return () => observer.disconnect();
  }, []);

  return isDarkMode;
}

/**
 * @explorer-desc
 * A component for rendering Excalidraw elements as a static image
 */
export default function ExcalidrawImage({
  elements,
  files,
  imageContainerRef,
  appState,
  rootClassName = null,
  width = 'inherit',
  height = 'inherit',
}: Props): JSX.Element {
  const [Svg, setSvg] = useState<SVGElement | null>(null);
  const isDarkMode = useAppDarkMode();

  useEffect(() => {
    let cancelled = false;

    const setContent = async () => {
      const svg: SVGElement = await exportToSvg({
        appState: {
          ...appState,
          exportBackground: false,
          exportWithDarkMode: isDarkMode,
        },
        elements,
        files,
      });
      removeStyleFromSvg_HACK(svg);
      svg.setAttribute('display', 'block');

      if (!cancelled) {
        setSvg(svg);
      }
    };
    setContent().catch(console.error);

    return () => {
      cancelled = true;
    };
  }, [elements, files, appState, isDarkMode]);

  const svgHtml = useMemo(() => {
    if (Svg == null) {
      return '';
    }
    const clone = Svg.cloneNode(true) as SVGElement;
    if (width === 'inherit' && height === 'inherit') {
      clone.style.maxWidth = '100%';
      clone.style.height = 'auto';
    } else {
      clone.setAttribute('width', '100%');
      clone.setAttribute('height', '100%');
    }
    return clone.outerHTML;
  }, [Svg, width, height]);

  const containerStyle: React.CSSProperties = {};
  if (width !== 'inherit') {
    containerStyle.width = `${width}px`;
  }
  if (height !== 'inherit') {
    containerStyle.height = `${height}px`;
  }

  return (
    <div
      ref={node => {
        if (node) {
          if (imageContainerRef) {
            imageContainerRef.current = node;
          }
        }
      }}
      className={rootClassName ?? ''}
      style={containerStyle}
      dangerouslySetInnerHTML={{__html: svgHtml}}
    />
  );
}
