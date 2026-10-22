import {useEffect, useState} from 'react';

export type AppTheme = 'dark' | 'light';

function readAppTheme(): AppTheme {
  return document.documentElement.dataset.theme === 'dark' ? 'dark' : 'light';
}

export default function useAppTheme(): AppTheme {
  const [theme, setTheme] = useState<AppTheme>(readAppTheme);

  useEffect(() => {
    const root = document.documentElement;
    const observer = new MutationObserver(() => setTheme(readAppTheme()));

    observer.observe(root, {
      attributeFilter: ['data-theme'],
      attributes: true,
    });

    return () => observer.disconnect();
  }, []);

  return theme;
}
