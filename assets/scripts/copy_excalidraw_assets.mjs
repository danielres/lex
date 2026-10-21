import {cpSync, mkdirSync} from "node:fs"
import {dirname, resolve} from "node:path"
import {fileURLToPath} from "node:url"

const assetsDirectory = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const source = resolve(
  assetsDirectory,
  "node_modules/@excalidraw/excalidraw/dist/prod/fonts",
)
const destination = resolve(assetsDirectory, "../priv/static/assets/fonts")

mkdirSync(destination, {recursive: true})
cpSync(source, destination, {recursive: true})
