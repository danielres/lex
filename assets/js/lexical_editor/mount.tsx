/**
 * The editor is derived from Meta's Lexical playground, licensed under MIT.
 */

import './index.css';

import {createRoot, type Root} from 'react-dom/client';

import PlaygroundApp from './App';
import './setupEnv';

export function mountLexicalEditor(element: HTMLElement): Root {
  const root = createRoot(element);
  root.render(<PlaygroundApp />);
  return root;
}
