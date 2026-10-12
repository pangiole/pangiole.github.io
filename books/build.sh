#!/usr/bin/env bash
#
# build.sh — build every mdBook under ./books/<slug>/ into
# ./static/books/<slug>/, so Zola copies them into the final `public/` output.
#
# Books are added as git submodules under `books/<slug>/`. Before building, each
# book submodule is initialised and updated to the commit recorded in this
# repository. The mdBook root inside each book — the directory holding its
# `book.toml` — is auto-detected, so a book may keep its sources in a `docs/`
# sub-directory, at the repository root, or anywhere in between.
#
# Requires: mdbook (and, if a book uses it, the mdbook-mermaid preprocessor).
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BOOKS_DIR="${REPO_ROOT}/books"
OUT_DIR="${REPO_ROOT}/static/books"

if [ ! -d "${BOOKS_DIR}" ]; then
    echo "==> No '${BOOKS_DIR}' directory — nothing to build."
    exit 0
fi

if ! command -v mdbook >/dev/null 2>&1; then
    echo "!! 'mdbook' not found on PATH. Install it first (e.g. 'brew install mdbook')." >&2
    exit 1
fi

# Initialise every book submodule and check it out at the commit recorded here.
if [ -f "${REPO_ROOT}/.gitmodules" ]; then
    while IFS= read -r submodule_path; do
        case "${submodule_path}" in
            books/*)
                echo "==> Updating submodule '${submodule_path}'"
                git -C "${REPO_ROOT}" submodule update --init --recursive -- "${submodule_path}"
                ;;
        esac
    done < <(git -C "${REPO_ROOT}" config -f .gitmodules --get-regexp '^submodule\..*\.path$' | awk '{print $2}')
fi

mkdir -p "${OUT_DIR}"

shopt -s nullglob
built=0
for book_dir in "${BOOKS_DIR}"/*/; do
    [ -d "${book_dir}" ] || continue
    slug="$(basename "${book_dir}")"

    # Skip submodules that were not initialised (empty working tree).
    if [ -z "$(ls -A "${book_dir}" 2>/dev/null)" ]; then
        echo "!! Skipping '${slug}': directory is empty (submodule not initialised?)."
        continue
    fi

    # Locate the mdBook root: the top-most directory containing a `book.toml`.
    book_toml="$(
        find "${book_dir}" -type f -name book.toml \
            -not -path '*/.git/*' \
            -not -path '*/target/*' \
            -not -path '*/node_modules/*' \
            2>/dev/null \
            | awk -F/ -v OFS='\t' '{print NF - 1, $0}' \
            | sort -k1,1n -k2,2 \
            | awk -F'\t' 'NR == 1 {print $2}'
    )"
    if [ -z "${book_toml}" ]; then
        echo "!! Skipping '${slug}': no book.toml found under '${slug}/'."
        continue
    fi
    book_root="$(dirname "${book_toml}")"

    dest="${OUT_DIR}/${slug}"
    echo "==> Building book '${slug}' from '${book_root}' → '${dest}'"
    rm -rf "${dest}"
    mdbook build "${book_root}" --dest-dir "${dest}"
    built=$((built + 1))
done

if [ "${built}" -eq 0 ]; then
    echo "==> No books to build."
else
    echo "==> Built ${built} book(s) into '${OUT_DIR}'."
fi
