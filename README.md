# pangiole.github.io

Personal site of **Paolo Angioletti** — a [Zola](https://www.getzola.org) static
site using the [tabi](https://github.com/welpo/tabi) theme. It hosts a landing
page, a curriculum, short articles, and longer books built with
[mdBook](https://rust-lang.github.io/mdBook/).

Live at <https://pangiole.github.io/>.

## Layout

```
config.toml                 Zola configuration (site + tabi settings)
content/
  _index.md                 Landing page
  curriculum.md             CV page (/curriculum/)
  articles/                 Short articles (/articles/<slug>/)
  books/_index.md           Books index page (/books/) — a curated list
books/<slug>/               Git submodules with the mdBook sources (/books/<slug>/)
books/build.sh              Builds every book into static/books/<slug>/
static/
  img/profile.*             Profile photo (placeholder — replace it!)
  books/                    Generated mdBook output (git-ignored)
themes/tabi                 tabi theme (git submodule)
.github/workflows/deploy.yml  Build + deploy to GitHub Pages
.github/workflows/update-books.yml  Bump book submodules on dispatch
```

## Requirements

- [Zola](https://www.getzola.org/documentation/getting-started/installation/) ≥ 0.23.6
- [mdBook](https://rust-lang.github.io/mdBook/guide/installation.html) (plus the
  `mdbook-mermaid` preprocessor if a book uses it)

On macOS: `brew install zola mdbook`. Install `mdbook-mermaid` via
`cargo install mdbook-mermaid` or the [prebuilt binaries](https://github.com/badboy/mdbook-mermaid/releases).

## Local development

```sh
git clone --recurse-submodules git@github.com:pangiole/pangiole.github.io.git
cd pangiole.github.io

# If you already cloned without submodules:
git submodule update --init --recursive

# Build the books into static/books/, then build/serve the site:
./books/build.sh
zola serve            # http://127.0.0.1:1111
```

`zola serve` rebuilds the Zola content on change. It does **not** rebuild the
books — re-run `./books/build.sh` after editing a book, then refresh.

To produce the final output: `./books/build.sh && zola build` (writes to `public/`).

## How the books work

Every book is a git submodule under `books/<slug>/`. `books/build.sh`
auto-detects each book's mdBook root (`<slug>/docs/book.toml` or
`<slug>/book.toml`) and builds it to `static/books/<slug>/`. Zola then copies
`static/` into `public/`, so each book is served at `/books/<slug>/` while the
`/books/` index page lists them.

Because the book is served under a sub-path of this site, the book's own
`site-url` (in its `book.toml`) is only used for the book's generated
`404.html` — all internal links are relative, so no change is required in the
book repository.

### Adding a book

```sh
git submodule add <book-repo-url> books/<slug>
git commit -m "Add <slug> book submodule"
```

Then add an entry to `content/books/_index.md` (title + one-line description +
link to `/books/<slug>/`). Run `./books/build.sh && zola build` to verify.

> [!TIP]
> Each book repository should disable its own GitHub Pages workflow, so the book
> is published only through this site (avoiding duplicate/conflicting content).

## Deployment

`.github/workflows/deploy.yml` runs on every push to `main`:

1. Checkout **with submodules**.
2. Install Zola, mdBook, and mdbook-mermaid.
3. `./books/build.sh` → builds the books.
4. `zola build` → writes `public/`.
5. Upload `public/` as a Pages artifact and deploy it.

In **Settings → Pages**, set the source to **GitHub Actions**.

### Automatic book updates

Each book repository (e.g. `oauth2-client`) dispatches an `update-books` event
to this repo whenever it is pushed to `main`. `.github/workflows/update-books.yml`
then bumps **every** submodule found under `books/` to its latest commit,
commits the new gitlinks, and pushes — which retriggers `deploy.yml`, so the
site redeploys with the fresh book. No manual gitlink bumping required.

Two repository secrets are needed (both fine-grained PATs with
**Contents: Read and write** on `pangiole/pangiole.github.io`):

- **`pangiole.github.io` → `BUMP_GITLINKS_TOKEN`** — used for the checkout and to push
  the bumped gitlink. A push made with the default `GITHUB_TOKEN` would **not**
  trigger `deploy.yml`, so a PAT is required here.
- **`oauth2-client` → `SITE_DISPATCH_TOKEN`** — sends the `repository_dispatch`
  event into this repo.

The workflow discovers book submodules from `.gitmodules` (any path matching
`books/*`), so adding a new book submodule is enough — no workflow edit needed.

## Placeholders to replace

- **`static/img/profile.webp`** — the profile photo (a temporary placeholder).
  Overwrite it with your own photo, or drop `static/img/profile.webp` and update
  the two references (`config.toml` → `hcard.avatar`; `content/_index.md` →
  `extra.header.img`).
- **`content/_index.md`** — the landing-page summary.
- **`content/curriculum.md`** — the CV.
- **`content/articles/welcome.md`** — a sample article to delete or replace.
