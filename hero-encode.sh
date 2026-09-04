#!/usr/bin/env bash
#
# hero-encode.sh — prépare une vidéo pour le hero scrubbé de waouw-v1.html
#
#   ./hero-encode.sh ma-nouvelle-video.mp4
#
# Produit, dans le dossier courant :
#   hero.mp4          la vidéo réencodée pour le scroll
#   hero-poster.jpg   sa première image (évite le flash noir à l'ouverture)
#
# Les deux doivent rester à côté de waouw-v1.html. Rien à reconstruire ensuite :
# on recharge la page, c'est à jour.
#
# ─────────────────────────────────────────────────────────────────────────────
# POURQUOI NE PAS SIMPLEMENT RENOMMER SON EXPORT EN hero.mp4
#
# Un encodage normal ne stocke une image complète que toutes les 2 à 10 secondes
# (une « image-clé ») ; entre deux, il ne garde que les différences. À la lecture
# c'est invisible. Au scrub, c'est fatal : chaque micro-mouvement du scroll oblige
# le décodeur à repartir de la dernière image-clé et à rejouer tout l'intervalle
# pour afficher UNE image. D'où le saccadement.
#
# On force donc une image-clé toutes les 4 images (keyint=4) : le décodeur n'a
# jamais plus de 3 images à rattraper. Le fichier grossit — c'est le prix du
# scrub fluide, et c'est un compromis assumé : keyint=1 (chaque image complète)
# doublerait encore le poids pour un gain imperceptible.
#
# Le reste :
#   -an            pas de son — la vidéo est muette par conception
#   bframes=0      pas d'images prédites depuis le futur, elles gênent la recherche
#   -r 30          30 im/s : au-delà, on paie des images que le scrub ne montre pas
#   scale=1152     largeur suffisante pour l'affichage réel, même sur écran retina
#   +faststart     l'index est placé en tête du fichier, lisible avant la fin
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

SRC="${1:-}"
if [ -z "$SRC" ] || [ ! -f "$SRC" ]; then
  echo "Usage : $0 <video-source>" >&2
  echo "Exemple : $0 ~/Downloads/dreamina-nouvelle-prise.mp4" >&2
  exit 1
fi

command -v ffmpeg >/dev/null 2>&1 || {
  echo "ffmpeg est introuvable. Sur macOS : brew install ffmpeg" >&2
  exit 1
}

DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Réencodage de « $SRC » pour le scrub…"
ffmpeg -hide_banner -loglevel error -y -i "$SRC" \
  -an -r 30 -vf "scale=1152:-2:flags=lanczos" \
  -c:v libx264 -preset slower -pix_fmt yuv420p \
  -x264-params "keyint=4:min-keyint=4:scenecut=0:bframes=0" \
  -crf 23 -movflags +faststart \
  "$DIR/hero.mp4"

echo "Extraction de l'image d'ouverture…"
ffmpeg -hide_banner -loglevel error -y -i "$DIR/hero.mp4" \
  -frames:v 1 -q:v 3 "$DIR/hero-poster.jpg"

SIZE=$(du -h "$DIR/hero.mp4" | cut -f1)
DUR=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$DIR/hero.mp4")

echo
echo "Terminé — hero.mp4 ($SIZE, ${DUR%.*} s) et hero-poster.jpg sont à jour."
echo "Recharger waouw-v1.html suffit."
echo
echo "Note : la durée n'a pas d'importance pour le réglage du scroll — la course"
echo "est répartie sur toute la longueur du plan, quelle qu'elle soit. En revanche"
echo "un plan très long paraîtra défiler vite ; au-delà d'une quinzaine de secondes,"
echo "mieux vaut rallonger la section hero (la règle .hero{height:240vh})."
