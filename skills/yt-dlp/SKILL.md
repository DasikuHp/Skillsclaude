---
name: yt-dlp
description: |
  Descarga vídeos y audio de YouTube, TikTok, X/Twitter, Vimeo, Instagram y
  cientos de sitios más, o extrae su metadata (título, duración, formatos,
  subtítulos) sin descargar. Usar cuando el usuario pida descargar un vídeo,
  sacar el audio/mp3, obtener info de una URL de vídeo, o recortar una sección.
  Incluye un binario yt-dlp autocontenido: no requiere pip ni el repo original.
---

# yt-dlp (herramienta vendorizada)

Binario zipapp autocontenido en `bin/yt-dlp` (construido desde el paquete
oficial de PyPI, versión 2026.07.04). Solo necesita `python3` — es
independiente del repo https://github.com/yt-dlp/yt-dlp y de pip.

## Invocación

```bash
SKILL_DIR="$(dirname "$0")"   # o la ruta de esta skill
python3 <ruta-de-esta-skill>/bin/yt-dlp [opciones] URL
```

También es ejecutable directamente (`./bin/yt-dlp`) si el sistema tiene
`/usr/bin/env python3`.

## Recetas clave

```bash
# Metadata sin descargar (JSON)
bin/yt-dlp -j --no-warnings "URL"

# Descargar mejor calidad hasta 1080p como mp4
bin/yt-dlp -f "bv*[height<=1080]+ba/b[height<=1080]/b" --merge-output-format mp4 \
  -o "salida/%(title).80s.%(ext)s" "URL"

# Solo audio mp3
bin/yt-dlp -x --audio-format mp3 --audio-quality 0 -o "salida/%(title).80s.%(ext)s" "URL"

# Solo una sección (recorte en descarga)
bin/yt-dlp --download-sections "*00:01:00-00:02:30" --force-keyframes-at-cuts "URL"

# Subtítulos (autogenerados incluidos) en srt
bin/yt-dlp --write-auto-subs --write-subs --sub-langs "es,en" --convert-subs srt --skip-download "URL"
```

Flags recomendados por defecto: `--no-playlist --no-warnings --restrict-filenames`.

## Notas

- Respeta el copyright y los Términos de Servicio de cada plataforma; descarga
  solo contenido que tengas derecho a usar.
- Para fusionar vídeo+audio o extraer mp3 hace falta `ffmpeg` en el PATH.
- Para actualizar el binario: `pip download yt-dlp --no-deps`, extraer el
  paquete `yt_dlp` del wheel, añadir un `__main__.py` que llame a
  `yt_dlp.main()` y empaquetar con
  `python3 -m zipapp <dir> -o yt-dlp -p "/usr/bin/env python3" -c`.
