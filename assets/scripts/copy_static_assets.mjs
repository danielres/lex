import {cpSync, mkdirSync} from "node:fs"
import {dirname, resolve} from "node:path"
import {fileURLToPath} from "node:url"

const assetsDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const copyDirectory = (source, destination) => {
  mkdirSync(destination, {recursive: true})
  cpSync(source, destination, {recursive: true})
}

copyDirectory(
  resolve(assetsDirectory, "node_modules/@excalidraw/excalidraw/dist/prod/fonts"),
  resolve(assetsDirectory, "../priv/static/assets/fonts"),
)

copyDirectory(
  resolve(assetsDirectory, "js/lexical_editor/images/emoji"),
  resolve(assetsDirectory, "../priv/static/assets/lexical/images/emoji"),
)

copyDirectory(
  resolve(assetsDirectory, "js/lexical_editor/images/icons"),
  resolve(assetsDirectory, "../priv/static/assets/lexical/images/icons"),
)

cpSync(
  resolve(assetsDirectory, "js/lexical_editor/images/logo.svg"),
  resolve(assetsDirectory, "../priv/static/assets/lexical/images/logo.svg"),
)
