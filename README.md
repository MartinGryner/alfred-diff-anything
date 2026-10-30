# Diff Anything for Alfred

Open two files, two folders, or two copied texts side by side in the Diff Anything app on your Mac.

## Requirements

- macOS 13 or later and Alfred 5 with the paid [Powerpack](https://www.alfredapp.com/powerpack/), which Alfred needs to run workflows.
- Diff Anything 1.7.0 or later from the Mac App Store. If the app is missing or older, the workflow says so and opens the Mac App Store.
- For **Compare the last two copied texts**: Clipboard History turned on in Alfred's Features.

## Install

1. Install [Diff Anything from the Mac App Store](https://apps.apple.com/app/id6795463996) and open it once.
2. Download **Diff Anything.alfredworkflow** from the [latest release](https://github.com/MartinGryner/alfred-diff-anything/releases/latest).
3. Open the downloaded workflow to import it into Alfred. The workflow is free and its source is available here under the MIT License.

## Commands

**Compare in Diff Anything** (file action). Find the first file or folder in Alfred and add it to the File Buffer with ⌥↑, do the same with the second, then press ⌥→ to act on both and choose **Compare in Diff Anything**. The first item opens on the left, the second on the right.

**diff** (keyword). Select two files or two folders in Finder, then type `diff` in Alfred. If the sides come out the wrong way round, swap them with the swap button beside **Open Right** in Diff Anything.

**diffclip** (keyword). Copy one text, then another, then type `diffclip` in Alfred. The earlier copy opens on the left, the latest on the right.

Each comparison opens in a new Diff Anything tab, with the features and limits of your Diff Anything plan. Purchase or restore Pro in the app. Both keywords can be changed in the workflow's configuration.

For a quick example, copy `Bread 3.50`, then `Bread 3.80`, and run `diffclip`. The earlier price is on the left and the latest on the right. The `examples/` folder also has two small bakery folders: a price changes, opening hours change, and one note is removed.

## Free and Pro

The workflow itself is free. Diff Anything Free allows 10 new comparison sessions per local day with files up to 5 MiB per side. Folder and archive comparisons preview the first 100 items; CSV previews show 100 rows, binary previews show 100 byte differences and PDF previews show 3 pages. A one-time Pro purchase in Diff Anything removes these preview and session limits within technical safety limits, and adds merging, folder copying and synchronization, profiles, history, and report export.

## Privacy

The workflow makes no network requests and sends nothing to an AI model. It hands your files to Diff Anything through macOS and never changes them. It reads the Finder selection only when you use `diff`, and the last two Clipboard History items only when you use `diffclip`.

`diffclip` saves the two texts as private files (folder mode 0700, file mode 0600) in the workflow's cache folder so Diff Anything can open them. A later text comparison removes pairs older than a day. Deletion is not secure erasure.

## Source

`workflow/diffanything.sh` does the work; `build.py` writes Alfred's `info.plist` and packages `dist/Diff Anything.alfredworkflow`; `tests/test.sh` runs the script against a stand-in app. `examples/` holds a small folder pair to try.

MIT License.

## Development disclosure

This workflow was created with Claude Code and reviewed with OpenAI Codex. Comparisons run locally in Diff Anything and send no data to an AI model.
