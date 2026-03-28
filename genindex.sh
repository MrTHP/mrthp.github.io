#!/bin/bash

# Utilise le répertoire courant
WEBROOT="$(pwd)"

# Génère le fichier index.html
{
  echo '<!DOCTYPE html>'
  echo '<html><head><meta charset="UTF-8">'
  echo "<title>Index of $WEBROOT</title>"
  echo '</head><body>'
  echo "<h1><center>Index of $WEBROOT</center></h1>"
  echo '<ul>'

  for item in *; do
    # Ne pas inclure l'index.html lui-même
    if [[ "$item" != "index.html" ]]; then
      # Ajouter un "/" si c'est un dossier
      if [[ -d "$item" ]]; then
        echo "<li><a href=\"$item/\">$item/</a></li>"
      else
        echo "<li><a href=\"$item\">$item</a></li>"
      fi
    fi
  done

  echo '</ul>'
  echo '</body></html>'
} > "$WEBROOT/index.html"

echo "✔️ Nouveau index.html généré dans $WEBROOT"
