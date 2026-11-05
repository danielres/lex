# live_lexical

Reusable Lexical editor source for Phoenix applications.

The package owns the generic editor, its baseline styles, and its static assets.
Each application owns its Phoenix hooks, collaboration transport, domain-specific
nodes and plugins, and visual adapter.

This is currently a source package rather than a separately built or published
npm package. The consuming application owns the JavaScript dependency tree and
bundles the source with its normal asset pipeline.

## Add the source package

Place the package at `packages/live_lexical` and reference it from the
application's `assets/package.json`:

```json
{
  "dependencies": {
    "live_lexical": "file:../packages/live_lexical"
  }
}
```

The application must also provide the React, Lexical, Yjs, and editor feature
dependencies used by the package. Until the dependency surface stabilizes,
`assets/package.json` in this repository is the reference manifest.

Add the package's build requirements to the consuming application's esbuild
arguments. Keeping them in a named list makes the integration boundary visible
without hiding it behind a helper:

```elixir
live_lexical_esbuild_args =
  ~w(
    --jsx=automatic
    --preserve-symlinks
    --loader:.gif=file
    --loader:.jpg=file
    --loader:.png=file
    --loader:.svg=file
    --loader:.ttf=file
    --loader:.woff=file
    --loader:.woff2=file
    --define:process.env.EXCALIDRAW_ASSET_PATH="/assets/"
  )

config :esbuild,
  lex: [
    args: ~w(js/app.js --bundle ...) ++ live_lexical_esbuild_args,
    cd: Path.expand("../assets", __DIR__)
  ]
```

The automatic JSX runtime lets package components use JSX without a global
`React` value. Preserving symlinks allows linked source-package dependencies to
resolve through the consuming application. The loaders and Excalidraw asset
path support static assets imported by the editor and its dependencies.

## Import the styles

Import the generic editor styles before application-specific adapter styles in
`assets/css/app.css`:

```css
@import "live_lexical/styles.css";
@import "./lexical-adapter/theme.css";
@import "./lexical-adapter/revision.css";
@import "./lexical-adapter/wiki.css";

@source "../../packages/live_lexical/assets/js";
```

The package styles provide structural defaults and CSS variables. The adapter
owns application colors, theme mapping, and domain-specific presentation.

## Provide an adapter

The application adapter connects the generic editor to application behavior.
In this project it lives in `assets/js/lexical_adapter` and owns:

- Phoenix and Yjs collaboration
- LiveView hooks
- wiki links and page lookup
- application-specific nodes and extensions
- collaborator and revision data mapping
- theme and layout integration

The package exposes focused entry points for collaboration types, editor
integration, mounting, revision previews, selection helpers, styles, and URL
helpers. Import those entry points through `live_lexical/*`; do not import
package internals from the adapter.

Register the adapter's hooks in `assets/js/app.js`:

```js
import {createLexicalHooks} from "./lexical_adapter/hooks"

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: {
    ...createLexicalHooks(csrfToken),
  },
})
```

## Copy static assets

The package references editor icons and Excalidraw fonts from Phoenix static
paths. The consuming application should copy them into `priv/static/assets`
before building or deploying assets.

This project keeps that operation in
`assets/scripts/copy_static_assets.mjs` and runs it from each relevant Mix
alias:

```elixir
"assets.setup": [
  "ash_typescript.npm_install",
  "cmd --cd assets npm run copy:static-assets"
],
"assets.build": [
  "compile",
  "cmd --cd assets npm run copy:static-assets",
  "tailwind lex",
  "esbuild lex"
],
"assets.deploy": [
  "cmd --cd assets npm run copy:static-assets",
  "tailwind lex --minify",
  "esbuild lex --minify",
  "phx.digest"
]
```

The exact setup command can differ between projects; the invariant is that the
static files exist before Phoenix digests the asset tree.
