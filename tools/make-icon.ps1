# Generates the Power Plate addon icon: one nameplate drawn like the game's own,
# measured from a reference screenshot (see art\ref when present).
#   PowerPlate\Icon.tga   128x128 32-bit TGA used by the addon list (## IconTexture)
#   art\Icon-512.png      512x512 master, for previews and future edits
#
# Run:  powershell -NoProfile -ExecutionPolicy Bypass -File tools\make-icon.ps1
#
# The game draws names in Friz Quadrata, which is not shipped with Windows and
# lives inside the game's data archives. By default this uses the closest
# installed face. To use the real font, extract FRIZQT__.TTF and run:
#   ... -File tools\make-icon.ps1 -FontFile C:\path\to\FRIZQT__.TTF

param(
	[string]$FontFile = "",
	[string]$FontName = "Palatino Linotype",
	[string]$Text = "PowerPlate",
	[string]$Level = "??"   # "??" is what the game shows for a much higher-level opponent
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root   = Split-Path -Parent $PSScriptRoot
$tgaOut = Join-Path $root "PowerPlate\Icon.tga"
$pngOut = Join-Path $root "art\Icon-512.png"
New-Item -ItemType Directory -Force -Path (Split-Path $pngOut) | Out-Null

# ---------------------------------------------------------------------------
# Palette: one flat color per element (in-game shading intentionally ignored)
# ---------------------------------------------------------------------------
$cBackdrop = "#232c3f"   # dark slate, like the night-time ground behind the plate
$cYellow   = "#ede95c"   # outer outline of the plate
$cBronze   = "#a58c88"   # metal frame (a pinkish gray in the screenshot)
$cEdge     = "#1c1408"   # dark hairlines either side of the frame
$cFill     = "#dd1bd8"   # health bar magenta
$cName     = "#d02ed2"   # name text magenta
$cNameLine = "#25002a"   # dark outline around the name text
$cBadge    = "#17110a"   # level badge interior
$cLevel    = "#f0e050"   # level number yellow

# ---------------------------------------------------------------------------
# Geometry in "game pixels" (u) measured from the screenshot, scaled by $K.
# The plate is drawn shorter than in-game so it fills a square icon.
# ---------------------------------------------------------------------------
$S = 512
$K = 4.8
$yellowT  = 2.5   # yellow outline thickness
$rim      = 4.0   # dark edge 1 + bronze 2 + dark 1, on every side of the fill
$frameH   = 19.0  # frame height (fill is 11 tall)
$barW     = 68.0  # bar frame width
$badgeW   = 22.0  # level badge frame width
$gap      = 2.0   # yellow divider visible between bar and badge frames
$fontEm   = 13.0  # name text size
$capH     = 9.5   # approximate cap height at that size

function C([string]$hex, [int]$a = 255) {
	$h = $hex.TrimStart('#')
	[Drawing.Color]::FromArgb($a,
		[Convert]::ToInt32($h.Substring(0, 2), 16),
		[Convert]::ToInt32($h.Substring(2, 2), 16),
		[Convert]::ToInt32($h.Substring(4, 2), 16))
}

function RR([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
	$p = New-Object Drawing.Drawing2D.GraphicsPath
	$d = [Math]::Min($r * 2, [Math]::Min($w, $h))
	$p.AddArc($x, $y, $d, $d, 180, 90)
	$p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
	$p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
	$p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
	$p.CloseFigure()
	return $p
}

function Fill($g, [string]$hex, $path) {
	$b = New-Object Drawing.SolidBrush (C $hex)
	$g.FillPath($b, $path); $b.Dispose(); $path.Dispose()
}

# Frame in game units -> pixels. Draws edge, bronze, inner dark, then returns the fill rect.
function DrawFrame($g, [float]$x, [float]$y, [float]$w, [float]$h, [string]$interiorHex) {
	Fill $g $cEdge   (RR $x $y $w $h (2.6 * $K))
	Fill $g $cBronze (RR ($x + 1 * $K) ($y + 1 * $K) ($w - 2 * $K) ($h - 2 * $K) (1.9 * $K))
	Fill $g $cEdge   (RR ($x + 3 * $K) ($y + 3 * $K) ($w - 6 * $K) ($h - 6 * $K) (1.0 * $K))
	Fill $g $interiorHex (RR ($x + 4 * $K) ($y + 4 * $K) ($w - 8 * $K) ($h - 8 * $K) (0.8 * $K))
}

# Text drawn as: soft drop shadow, dark outline, flat fill. Centered on ($cx, $baseline).
function DrawGameText($g, [string]$s, $family, [float]$emPx, [float]$cx, [float]$baseline, [string]$fillHex, [string]$outlineHex, [float]$outlinePx, [float]$shadowPx) {
	$sf = New-Object Drawing.StringFormat ([Drawing.StringFormat]::GenericTypographic)
	$style = [Drawing.FontStyle]::Bold
	# Measure with an origin at 0,0 to center horizontally, and place by baseline.
	$probe = New-Object Drawing.Drawing2D.GraphicsPath
	$probe.AddString($s, $family, [int]$style, $emPx, (New-Object Drawing.PointF 0, 0), $sf)
	$bounds = $probe.GetBounds(); $probe.Dispose()
	$ascent = $family.GetCellAscent($style) / $family.GetEmHeight($style) * $emPx
	$ox = $cx - ($bounds.X + $bounds.Width / 2)
	$oy = $baseline - $ascent

	$path = New-Object Drawing.Drawing2D.GraphicsPath
	$path.AddString($s, $family, [int]$style, $emPx, (New-Object Drawing.PointF $ox, $oy), $sf)

	$shadowPath = $path.Clone()
	$m = New-Object Drawing.Drawing2D.Matrix; $m.Translate($shadowPx, $shadowPx); $shadowPath.Transform($m)
	$pen = New-Object Drawing.Pen (C "#000000" 190), ($outlinePx * 2)
	$pen.LineJoin = "Round"
	$g.DrawPath($pen, $shadowPath)
	$sb = New-Object Drawing.SolidBrush (C "#000000" 190); $g.FillPath($sb, $shadowPath)
	$pen.Dispose(); $sb.Dispose(); $shadowPath.Dispose()

	$pen = New-Object Drawing.Pen (C $outlineHex), ($outlinePx * 2)
	$pen.LineJoin = "Round"
	$g.DrawPath($pen, $path)
	$fb = New-Object Drawing.SolidBrush (C $fillHex)
	$g.FillPath($fb, $path)
	$pen.Dispose(); $fb.Dispose(); $path.Dispose(); $sf.Dispose()
}

# ---------------------------------------------------------------------------
# Font
# ---------------------------------------------------------------------------
$pfc = $null
if ($FontFile -and (Test-Path -LiteralPath $FontFile)) {
	$pfc = New-Object Drawing.Text.PrivateFontCollection
	$pfc.AddFontFile((Resolve-Path -LiteralPath $FontFile).Path)
	$family = $pfc.Families[0]
	Write-Output "Font: $($family.Name) (from $FontFile)"
} else {
	$family = New-Object Drawing.FontFamily $FontName
	Write-Output "Font: $FontName (installed stand-in for Friz Quadrata)"
}
if (-not $family.IsStyleAvailable([Drawing.FontStyle]::Bold)) { throw "Font has no bold style." }

# ---------------------------------------------------------------------------
# Draw
# ---------------------------------------------------------------------------
$bmp = New-Object Drawing.Bitmap $S, $S, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = "AntiAlias"
$g.InterpolationMode = "HighQualityBicubic"
$g.PixelOffsetMode = "HighQuality"
$g.Clear([Drawing.Color]::Transparent)

# Flat backdrop
Fill $g $cBackdrop (RR 0 0 $S $S 56)
$rimPen = New-Object Drawing.Pen (C "#000000" 120), 6
$rp = RR 3 3 ($S - 6) ($S - 6) 54; $g.DrawPath($rimPen, $rp); $rp.Dispose(); $rimPen.Dispose()

# Plate placement: centered, with the name sitting on the top edge like in-game
$plateW  = ($yellowT + $barW + $gap + $badgeW + $yellowT) * $K
$plateH  = ($yellowT * 2 + $frameH) * $K
$x0      = ($S - $plateW) / 2
$stackH  = ($capH - 2 + $yellowT * 2 + $frameH) * $K
$capTop  = ($S - $stackH) / 2
$baseline = $capTop + $capH * $K
$yTop    = $baseline - 2 * $K                # yellow outline top edge
$fy      = $yTop + $yellowT * $K             # frame top

$barX   = $x0 + $yellowT * $K
$badgeX = $barX + ($barW + $gap) * $K
$barPx  = $barW * $K
$badgePx = $badgeW * $K
$frameHPx = $frameH * $K

# 1) Yellow outline: both frames expanded, merging across the divider
$e = $yellowT * $K
Fill $g $cYellow (RR ($barX - $e) ($fy - $e) ($barPx + 2 * $e) ($frameHPx + 2 * $e) (4.5 * $K))
Fill $g $cYellow (RR ($badgeX - $e) ($fy - $e) ($badgePx + 2 * $e) ($frameHPx + 2 * $e) (4.5 * $K))
# bridge so the divider is solid yellow top to bottom
$gb = New-Object Drawing.SolidBrush (C $cYellow)
$g.FillRectangle($gb, ($barX + $barPx - 4 * $K), ($fy - $e + 3 * $K), (($badgeX - ($barX + $barPx)) + 8 * $K), ($frameHPx + 2 * $e - 6 * $K))
$gb.Dispose()

# 2) Frames
DrawFrame $g $barX   $fy $barPx   $frameHPx $cFill
DrawFrame $g $badgeX $fy $badgePx $frameHPx $cBadge

# 3) Name text, centered over the bar
DrawGameText $g $Text $family ($fontEm * $K) ($barX + $barPx / 2) $baseline $cName $cNameLine (0.9 * $K) (0.9 * $K)

# 4) Level number, centered in the badge
$lvlBase = $fy + $frameHPx / 2 + 4.0 * $K
DrawGameText $g $Level $family (11.5 * $K) ($badgeX + $badgePx / 2) $lvlBase $cLevel "#000000" (0.55 * $K) (0.6 * $K)

$g.Dispose()
$bmp.Save($pngOut, [Drawing.Imaging.ImageFormat]::Png)

# ---------------------------------------------------------------------------
# Downsample to 128x128 and write a 32-bit uncompressed TGA
# ---------------------------------------------------------------------------
$N = 128
$small = New-Object Drawing.Bitmap $N, $N, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g2 = [Drawing.Graphics]::FromImage($small)
$g2.Clear([Drawing.Color]::Transparent)
$g2.InterpolationMode = "HighQualityBicubic"
$g2.SmoothingMode = "HighQuality"
$g2.PixelOffsetMode = "HighQuality"
$g2.CompositingMode = "SourceCopy"
$g2.DrawImage($bmp, (New-Object Drawing.Rectangle 0, 0, $N, $N), 0, 0, $S, $S, ([Drawing.GraphicsUnit]::Pixel))
$g2.Dispose()

$rect = New-Object Drawing.Rectangle 0, 0, $N, $N
$data = $small.LockBits($rect, ([Drawing.Imaging.ImageLockMode]::ReadOnly), ([Drawing.Imaging.PixelFormat]::Format32bppArgb))
$pixels = New-Object byte[] ($N * $N * 4)
[Runtime.InteropServices.Marshal]::Copy($data.Scan0, $pixels, 0, $pixels.Length)  # BGRA, top-down
$small.UnlockBits($data)

$header = New-Object byte[] 18
$header[2]  = 2                       # uncompressed true-color
$header[12] = $N -band 0xFF; $header[13] = ($N -shr 8) -band 0xFF
$header[14] = $N -band 0xFF; $header[15] = ($N -shr 8) -band 0xFF
$header[16] = 32                      # bits per pixel
$header[17] = 0x28                    # 8 alpha bits, top-left origin

$fs = [IO.File]::Open($tgaOut, [IO.FileMode]::Create)
$fs.Write($header, 0, 18)
$fs.Write($pixels, 0, $pixels.Length)
$fs.Close()

# --- Pixelated 512 preview: each of the 128x128 pixels becomes an exact 4x4 block ---
$F = 4; $O = $N * $F
$px = New-Object Drawing.Bitmap $O, $O, ([Drawing.Imaging.PixelFormat]::Format32bppArgb)
$pd = $px.LockBits((New-Object Drawing.Rectangle 0, 0, $O, $O), ([Drawing.Imaging.ImageLockMode]::WriteOnly), ([Drawing.Imaging.PixelFormat]::Format32bppArgb))
$big = New-Object byte[] ($O * $O * 4)
for ($y = 0; $y -lt $N; $y++) {
	for ($x = 0; $x -lt $N; $x++) {
		$si = ($y * $N + $x) * 4
		for ($dy = 0; $dy -lt $F; $dy++) {
			for ($dx = 0; $dx -lt $F; $dx++) {
				$di = ((($y * $F + $dy) * $O) + ($x * $F + $dx)) * 4
				$big[$di] = $pixels[$si]; $big[$di + 1] = $pixels[$si + 1]
				$big[$di + 2] = $pixels[$si + 2]; $big[$di + 3] = $pixels[$si + 3]
			}
		}
	}
}
[Runtime.InteropServices.Marshal]::Copy($big, 0, $pd.Scan0, $big.Length)
$px.UnlockBits($pd)
$pixelOut = Join-Path $root "art\icon-512-pixelated.png"
$px.Save($pixelOut, [Drawing.Imaging.ImageFormat]::Png)
$px.Dispose()

$small.Dispose(); $bmp.Dispose()
Write-Output "Wrote $tgaOut"
Write-Output "Wrote $pngOut"
Write-Output "Wrote $pixelOut"
