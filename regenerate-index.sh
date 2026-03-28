#!/bin/bash

WEBROOT="/home/mrthp/Public"
STYLE="theme.css"
WALLPAPER="wallpaper.jpg"

cd "$WEBROOT" || exit 1

# Génère le fichier index.html
{
  echo '<!DOCTYPE html>'
  echo '<html><head><meta charset="UTF-8">'
  echo '<title>Index of /home/mrthp</title>'
  echo '<link rel="stylesheet" href="/theme.css">'  # 👈 CHEMIN ABSOLU
  echo '</head><body><h1><center>Index of /home/mrthp/</center></h1><ul>'

  for item in *; do
    if [[ "$item" != "$STYLE" && "$item" != "index.html" && "$item" != "$WALLPAPER" ]]; then
      echo "<li><a href=\"$item\">$item</a></li>"
    fi
  done

  echo '</ul></body></html>'
} > "$WEBROOT/index.html"

echo "✔️ Nouveau index.html généré avec le bon lien CSS"
