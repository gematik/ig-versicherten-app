#!/bin/zsh
# ============================================================================
# Lokaler Build des GitHub Pages Inhalts
# Bildet den deploy-pages.yml Workflow nach und startet einen lokalen Server.
#
# Nutzung:
#   ./scripts/build-pages-local.sh          # Baut und startet Server auf Port 8000
#   ./scripts/build-pages-local.sh --build  # Nur bauen, kein Server
# ============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

BUILD_ONLY=false
[[ "${1:-}" == "--build" ]] && BUILD_ONLY=true

echo "🧹 Räume vorherige Builds auf..."
rm -rf _site _generated_index.adoc

echo "📄 Generiere dynamische index.adoc..."
mkdir -p _site

printf '%s\n' \
  '= App des Versicherten' \
  ':toc: left' \
  ':toclevels: 3' \
  ':imagesdir: images' \
  '' \
  'include::docs/app_overview.adoc[leveloffset=+1]' \
  '' \
  '== Module' \
  > _generated_index.adoc

# --- Dynamisch alle Module unter modules/ auflisten ---
for module_dir in modules/*/; do
  module_name="$(basename "$module_dir")"
  overview_file="${module_dir}docs/overview.adoc"
  if [ -f "$overview_file" ]; then
    # --- SVG-Icon für das Modul generieren ---
    icon_file="_site/images/module_${module_name}.svg"
    mkdir -p _site/images
    text_len=${#module_name}
    width=$(( text_len * 10 + 24 ))
    half=$(( width / 2 ))
    {
      echo "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"${width}\" height=\"28\" viewBox=\"0 0 ${width} 28\">"
      echo "  <rect width=\"${width}\" height=\"28\" rx=\"6\" fill=\"#0b6abf\"/>"
      echo "  <text x=\"${half}\" y=\"18\" font-family=\"Arial, Helvetica, sans-serif\" font-size=\"13\" font-weight=\"bold\" fill=\"#fff\" text-anchor=\"middle\">${module_name}</text>"
      echo "</svg>"
    } > "$icon_file"

    echo "" >> _generated_index.adoc
    echo "image:module_${module_name}.svg[link=modules/${module_name}/docs/overview.html,title=${module_name}]" >> _generated_index.adoc
  fi
done


# --- index.html erzeugen ---
echo "🔨 Konvertiere index.adoc → index.html..."
asciidoctor -b html5 -o _site/index.html _generated_index.adoc

# --- docs/ konvertieren ---
echo "🔨 Konvertiere docs/*.adoc..."
mkdir -p _site/docs
for f in docs/*.adoc; do
  [ -f "$f" ] || continue
  asciidoctor -b html5 -a imagesdir=../images \
    -o "_site/docs/$(basename "${f%.adoc}.html")" "$f"
done

# --- Modul-Docs konvertieren ---
echo "🔨 Konvertiere Modul-Dokumente..."
find modules -name "*.adoc" -path "*/docs/*" | while read f; do
  outpath="_site/${f%.adoc}.html"
  mkdir -p "$(dirname "$outpath")"
  asciidoctor -b html5 -o "$outpath" "$f"
done

# --- Bilder kopieren ---
echo "🖼️  Kopiere Bilder..."
if [ -d "images" ]; then
  mkdir -p _site/images
  cp -r images/* _site/images/ 2>/dev/null || true
fi

find modules -type d -name "images" | while read imgdir; do
  mkdir -p "_site/$imgdir"
  cp -r "$imgdir"/* "_site/$imgdir"/ 2>/dev/null || true
done

# --- .adoc Links → .html Links in generierten HTML-Dateien ---
echo "🔗 Korrigiere interne Links (.adoc → .html)..."
# macOS sed benötigt '' nach -i
find _site -name "*.html" -exec sed -i '' \
  -e 's/\.adoc"/\.html"/g' \
  -e "s/\.adoc'/\.html'/g" \
  -e 's/\.adoc#/\.html#/g' \
  -e 's/\.adoc<\/a>/\.html<\/a>/g' \
  {} +

# --- Docinfo (CSS/JS) in alle HTML-Dateien injizieren ---
echo "🎨 Injiziere docinfo.html in alle HTML-Dateien..."
DOCINFO_FILE="$PROJECT_ROOT/docinfo.html"
if [ -f "$DOCINFO_FILE" ]; then
  for htmlfile in $(find _site -name "*.html"); do
    awk -v docinfo="$DOCINFO_FILE" '
      /<\/head>/ {
        while ((getline line < docinfo) > 0) print line
        close(docinfo)
      }
      { print }
    ' "$htmlfile" > "${htmlfile}.tmp" && mv "${htmlfile}.tmp" "$htmlfile"
  done
fi

# --- Aufräumen ---
rm -f _generated_index.adoc

# --- Übersicht ---
echo ""
echo "✅ Build fertig! Generierte Dateien:"
find _site -type f | sort | sed 's/^/   /'
echo ""

if $BUILD_ONLY; then
  echo "📂 Ergebnis liegt in: $PROJECT_ROOT/_site/"
  exit 0
fi

# --- Lokalen Webserver starten ---
echo "🌐 Starte lokalen Server auf http://localhost:8000"
echo "   Beende mit Ctrl+C"
echo ""
cd _site
python3 -m http.server 8000

