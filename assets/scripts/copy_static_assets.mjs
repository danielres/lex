import {cpSync, mkdirSync, rmSync} from "node:fs"
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

const lexicalImagesDirectory = resolve(
  assetsDirectory,
  "../priv/static/assets/lexical/images",
)

rmSync(lexicalImagesDirectory, {recursive: true, force: true})

copyDirectory(
  resolve(assetsDirectory, "css/lexical/images"),
  lexicalImagesDirectory,
)
