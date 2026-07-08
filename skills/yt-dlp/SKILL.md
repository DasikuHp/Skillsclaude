---
name: yt-dlp
description: |
  Descarga vídeos y audio de YouTube, TikTok, X/Twitter, Vimeo, Instagram y
  cientos de sitios más, o extrae su metadata (título, duración, formatos,
  subtítulos) sin descargar. Usar cuando el usuario pida descargar un vídeo,
  sacar el audio/mp3, obtener info de una URL de vídeo, o recortar una sección.
  Incluye yt-dlp y ffmpeg/ffprobe autocontenidos: no requiere pip, instalar
  ffmpeg, ni el repo original.
---

# yt-dlp (herramienta vendorizada, con ffmpeg incluido)

Todo vive en `bin/`, independiente del repo https://github.com/yt-dlp/yt-dlp
y de pip:

- `bin/yt-dlp` — zipapp autocontenido (paquete oficial de PyPI, 2026.07.04);
  solo necesita `python3`.
- `bin/ffmpeg` y `bin/ffprobe` — builds estáticos linux x86-64 (7.0.2,
  johnvansickle.com).
- `bin/ffmpeg.exe` y `bin/ffprobe.exe` — builds win64 (8.1.2 essentials,
  gyan.dev). En Windows, ya están "junto a yt-dlp" como pide la doc oficial.
- `bin/yt-dlp.bat` (CMD) y `bin/yt-dlp.ps1` (PowerShell) — lanzadores para
  Windows que localizan Python y pasan `--ffmpeg-location` automáticamente.

Licencia GPL de ffmpeg en `bin/LICENSE-ffmpeg-*.txt`.

> Ensamblado y verificado en Linux (contenedor de Claude Code); los `.exe`
> son los builds oficiales win64 sin modificar y no se ejecutaron en ese
> entorno. En Windows solo se necesita Python 3.9+ (python.org o Microsoft
> Store) — ni pip, ni ffmpeg del sistema.

## Invocación

```bash
SKILL_DIR="$(dirname "$0")"   # o la ruta de esta skill
python3 <ruta-de-esta-skill>/bin/yt-dlp [opciones] URL
```

También es ejecutable directamente (`./bin/yt-dlp`) si el sistema tiene
`/usr/bin/env python3`.

**En Windows** usa los lanzadores (añaden `--ffmpeg-location` solos):

```bat
bin\yt-dlp.bat [opciones] URL      &:: CMD
```
```powershell
.\bin\yt-dlp.ps1 [opciones] URL    # PowerShell
```

## Recetas clave

```bash
# Metadata sin descargar (JSON)
bin/yt-dlp -j --no-warnings "URL"

# Descargar mejor calidad hasta 1080p como mp4 (usa el ffmpeg incluido para fusionar)
bin/yt-dlp --ffmpeg-location bin/ -f "bv*[height<=1080]+ba/b[height<=1080]/b" \
  --merge-output-format mp4 -o "salida/%(title).80s.%(ext)s" "URL"

# Solo audio mp3 (usa el ffmpeg incluido para extraer)
bin/yt-dlp --ffmpeg-location bin/ -x --audio-format mp3 --audio-quality 0 \
  -o "salida/%(title).80s.%(ext)s" "URL"

# Solo una sección (recorte en descarga)
bin/yt-dlp --download-sections "*00:01:00-00:02:30" --force-keyframes-at-cuts "URL"

# Subtítulos (autogenerados incluidos) en srt
bin/yt-dlp --write-auto-subs --write-subs --sub-langs "es,en" --convert-subs srt --skip-download "URL"
```

Flags recomendados por defecto: `--no-playlist --no-warnings --restrict-filenames`.

## Notas

- Respeta el copyright y los Términos de Servicio de cada plataforma; descarga
  solo contenido que tengas derecho a usar.
- Pasa siempre `--ffmpeg-location <ruta-de-esta-skill>/bin` para usar el ffmpeg
  incluido (fusionar vídeo+audio, extraer mp3, recortes). Sin ese flag, yt-dlp
  buscará ffmpeg en el PATH.
- `bin/ffprobe` (o `ffprobe.exe`) sirve para inspeccionar cualquier fichero:
  `bin/ffprobe -v error -show_format -show_streams -of json fichero.mp4`.
- Para actualizar el binario: `pip download yt-dlp --no-deps`, extraer el
  paquete `yt_dlp` del wheel, añadir un `__main__.py` que llame a
  `yt_dlp.main()` y empaquetar con
  `python3 -m zipapp <dir> -o yt-dlp -p "/usr/bin/env python3" -c`.
