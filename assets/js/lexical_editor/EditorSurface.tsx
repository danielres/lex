import type {JSX, ReactNode} from 'react';

import useAppTheme from './hooks/useAppTheme';

export default function EditorSurface({
  children,
  className,
  editable,
}: {
  children: ReactNode;
  className?: string;
  editable: boolean;
}): JSX.Element {
  const appTheme = useAppTheme();
  const classes = ['editor-shell', 'wiki-editor', className]
    .filter(Boolean)
    .join(' ');

  return (
    <div className={classes} data-app-theme={appTheme} data-editable={editable}>
      {children}
    </div>
  );
}
