# Draws Gear Set Colors' icon: four bag slots. Three hold gear and wear the colour of their equipment set
# (border and tint, as the addon marks them in the bags); the fourth holds a potion, in no set, unmarked.
#
#   powershell -File scripts/make-icon.ps1 -Out curseforge/logo.png -Size 512        # CurseForge avatar
#   powershell -File scripts/make-icon.ps1 -Out GearSetColors/media/icon.tga -Size 64 # in-game icon
#
# The picture is drawn at four times the size and scaled down, for smooth edges. Shapes are described in
# units: 0 to 1 across the icon, and 0 to 1 across each slot. A .tga is written as uncompressed 32-bit
# BGRA with bottom-up rows, which WoW reads as an addon texture (its size must be a power of two). Any
# other extension is written as PNG.
param([Parameter(Mandatory)][string]$Out, [int]$Size = 512)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$C = [System.Drawing.Color]
$S = $Size * 4

function Hex([string]$hex, [int]$alpha = 255) {
    $v = [Convert]::ToInt32($hex.TrimStart('#'), 16)
    return $C::FromArgb($alpha, ($v -shr 16) -band 255, ($v -shr 8) -band 255, $v -band 255)
}
# A colour from the addon's palette (Core.lua), given as 0-1 components.
function Rgb([double[]]$rgb, [int]$alpha = 255) {
    return $C::FromArgb($alpha, [int]($rgb[0] * 255), [int]($rgb[1] * 255), [int]($rgb[2] * 255))
}
function Pt([double]$x, [double]$y) { New-Object System.Drawing.PointF ([single]$x), ([single]$y) }
function RectF([double]$x, [double]$y, [double]$w, [double]$h) {
    New-Object System.Drawing.RectangleF ([single]$x), ([single]$y), ([single]$w), ([single]$h)
}
function Polygon([double[]]$xy) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $points = for ($i = 0; $i -lt $xy.Length; $i += 2) { Pt $xy[$i] $xy[$i + 1] }
    $path.AddPolygon([System.Drawing.PointF[]]$points)
    return $path
}
function Ellipse([double]$cx, [double]$cy, [double]$r) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddEllipse((RectF ($cx - $r) ($cy - $r) ($r * 2) ($r * 2)))
    return $path
}
function RoundedRect([double]$x, [double]$y, [double]$w, [double]$h, [double]$r) {
    $d = $r * 2
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc((RectF $x $y $d $d), 180, 90)
    $path.AddArc((RectF ($x + $w - $d) $y $d $d), 270, 90)
    $path.AddArc((RectF ($x + $w - $d) ($y + $h - $d) $d $d), 0, 90)
    $path.AddArc((RectF $x ($y + $h - $d) $d $d), 90, 90)
    $path.CloseFigure()
    return $path
}
# A linear gradient over the rectangle, through the given colours at the given positions (0 to 1).
# Angle 90 runs top to bottom, 0 left to right.
function GradientBrush($rect, [double]$angle, [System.Drawing.Color[]]$colors, [single[]]$positions) {
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $colors[0], $colors[-1], ([single]$angle)
    $blend = New-Object System.Drawing.Drawing2D.ColorBlend
    $blend.Colors = $colors
    $blend.Positions = $positions
    $brush.InterpolationColors = $blend
    return $brush
}
function Solid([System.Drawing.Color]$color) { New-Object System.Drawing.SolidBrush $color }

# The transform from a slot's units (0 to 1 across the slot) to pixels, with an optional shift (in slot
# units, after the rotation) and rotation about the slot's centre.
function SlotMatrix([double]$x, [double]$y, [double]$w, [double]$dx = 0, [double]$dy = 0, [double]$angle = 0) {
    $m = New-Object System.Drawing.Drawing2D.Matrix
    $m.Scale($S, $S)
    $m.Translate($x, $y)
    $m.Scale($w, $w)
    if ($dx -or $dy) { $m.Translate($dx, $dy) }
    if ($angle) { $m.RotateAt($angle, (Pt 0.5 0.5)) }
    return $m
}

# --- The gear, in slot units. Each is a list of shapes, @(path, brush), painted in order. ---

# A sword, drawn upright; it is turned 45 degrees when drawn, tip to the top right.
function Sword {
    $steel = GradientBrush (RectF 0.43 0 0.14 1) 0 @((Hex 'ffffff'), (Hex 'dfe6f2'), (Hex 'a7b2c6'), (Hex '76829a')) @(0.0, 0.5, 0.5, 1.0)
    $gold = GradientBrush (RectF 0 0.635 1 0.09) 90 @((Hex 'ffe796'), (Hex 'e9b448'), (Hex 'a8731f')) @(0.0, 0.5, 1.0)
    $goldBall = GradientBrush (RectF 0 0.855 1 0.13) 90 @((Hex 'ffe796'), (Hex 'e9b448'), (Hex 'a8731f')) @(0.0, 0.5, 1.0)
    $leather = GradientBrush (RectF 0.455 0 0.09 1) 0 @((Hex '8a5631'), (Hex '4a2914')) @(0.0, 1.0)
    return @(
        @((Polygon @(0.43, 0.16, 0.5, 0.0, 0.57, 0.16, 0.57, 0.65, 0.43, 0.65)), $steel),
        @((RoundedRect 0.455 0.69 0.09 0.18 0.02), $leather),
        @((RoundedRect 0.255 0.635 0.49 0.085 0.0425), $gold),
        @((Ellipse 0.5 0.915 0.062), $goldBall)
    )
}

# A closed helm seen from the front, with a T-shaped opening for the eyes and mouth.
function Helm {
    $body = New-Object System.Drawing.Drawing2D.GraphicsPath
    $body.AddLine((Pt 0.25 0.87), (Pt 0.225 0.52))
    $body.AddBezier((Pt 0.225 0.52), (Pt 0.225 0.26), (Pt 0.35 0.13), (Pt 0.5 0.13))
    $body.AddBezier((Pt 0.5 0.13), (Pt 0.65 0.13), (Pt 0.775 0.26), (Pt 0.775 0.52))
    $body.AddLine((Pt 0.775 0.52), (Pt 0.75 0.87))
    $body.CloseFigure()
    $steel = GradientBrush (RectF 0.225 0 0.55 1) 0 @((Hex 'f4f7fc'), (Hex 'c3ccdb'), (Hex '7a859b'), (Hex '5b6478')) @(0.0, 0.4, 0.85, 1.0)
    $dark = Solid (Hex '0f1117')
    $ridge = Solid (Hex 'ffffff' 150)
    return @(
        @($body, $steel),
        @((Polygon @(0.485, 0.15, 0.515, 0.15, 0.52, 0.43, 0.48, 0.43)), $ridge),
        @((RoundedRect 0.285 0.445 0.43 0.085 0.04), $dark),
        @((RoundedRect 0.455 0.47 0.09 0.4 0.03), $dark)
    )
}

# A heater shield: a gold rim, a blue field and a gold cross.
function ShieldPath([double]$l, [double]$t, [double]$r, [double]$mid, [double]$tip) {
    $mx = 0.5
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $p.AddLine((Pt $l $t), (Pt $r $t))
    $p.AddLine((Pt $r $t), (Pt $r $mid))
    $p.AddBezier((Pt $r $mid), (Pt $r ($mid + ($tip - $mid) * 0.55)), (Pt ($mx + ($r - $mx) * 0.6) ($tip - 0.07)), (Pt $mx $tip))
    $p.AddBezier((Pt $mx $tip), (Pt ($mx - ($mx - $l) * 0.6) ($tip - 0.07)), (Pt $l ($mid + ($tip - $mid) * 0.55)), (Pt $l $mid))
    $p.CloseFigure()
    return $p
}
function Shield {
    $rim = GradientBrush (RectF 0 0.14 1 0.76) 90 @((Hex 'ffe796'), (Hex 'd9a43c'), (Hex '9a671b')) @(0.0, 0.5, 1.0)
    $field = GradientBrush (RectF 0 0.2 1 0.64) 90 @((Hex '4a6fd0'), (Hex '27408f'), (Hex '182a63')) @(0.0, 0.55, 1.0)
    $cross = GradientBrush (RectF 0 0.2 1 0.64) 90 @((Hex 'fff1b8'), (Hex 'e7b950'), (Hex 'b98428')) @(0.0, 0.5, 1.0)
    return @(
        @((ShieldPath 0.2 0.14 0.8 0.47 0.9), $rim),
        @((ShieldPath 0.255 0.195 0.745 0.47 0.835), $field),
        @((RoundedRect 0.47 0.225 0.06 0.57 0.01), $cross),
        @((RoundedRect 0.3 0.39 0.4 0.06 0.01), $cross)
    )
}

# A round potion flask with violet liquid and a cork.
function Potion {
    $glass = Solid (Hex 'd8e6ff' 70)
    $liquid = GradientBrush (RectF 0 0.5 1 0.37) 90 @((Hex 'd36cf2'), (Hex '8a2bb8'), (Hex '4d1470')) @(0.0, 0.5, 1.0)
    $cork = GradientBrush (RectF 0.44 0 0.12 1) 0 @((Hex 'c08a5a'), (Hex '7a4d28')) @(0.0, 1.0)
    $rim = Solid (Hex 'e8f0ff' 200)
    $shine = Solid (Hex 'ffffff' 190)

    # The liquid fills the bulb from 0.53 down: the bulb's circle, cut flat at the top (a chord).
    $cx, $cy, $r, $top = 0.5, 0.625, 0.215, 0.53
    $half = [Math]::Acos(($top - $cy) / $r) * 180 / [Math]::PI   # angle from straight down to the chord's ends
    $liquidShape = New-Object System.Drawing.Drawing2D.GraphicsPath
    $liquidShape.AddArc((RectF ($cx - $r) ($cy - $r) ($r * 2) ($r * 2)), [single](90 - $half), [single](2 * $half))
    $liquidShape.CloseFigure()

    return @(
        @((Ellipse 0.5 0.625 0.235), $rim),
        @((Ellipse 0.5 0.625 0.215), (Solid (Hex '1d2230'))),
        @((Ellipse 0.5 0.625 0.215), $glass),
        @((RoundedRect 0.425 0.24 0.15 0.2 0.02), $rim),
        @((RoundedRect 0.44 0.255 0.12 0.2 0.015), (Solid (Hex '1d2230'))),
        @((RoundedRect 0.44 0.255 0.12 0.2 0.015), $glass),
        @($liquidShape, $liquid),
        @((RoundedRect 0.41 0.225 0.18 0.045 0.02), $rim),
        @((RoundedRect 0.445 0.14 0.11 0.1 0.02), $cork),
        @((Ellipse 0.41 0.55 0.035), $shine)
    )
}

# --- Drawing ---

$big = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($big)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality

# Background: a dark slate, lighter toward the middle, like the inside of a bag.
$g.Transform = SlotMatrix 0 0 1
$g.FillRectangle((Solid (Hex '0b0d12')), (RectF 0 0 1 1))
$glowPath = Ellipse 0.5 0.47 0.78
$glow = New-Object System.Drawing.Drawing2D.PathGradientBrush $glowPath
$glow.CenterColor = Hex '323949'
$glow.SurroundColors = @((Hex '0b0d12'))
$g.FillPath($glow, $glowPath)

# One bag slot at (x, y), w wide, in a set colour (0-1 components) or unmarked ($null), holding an item.
function Slot([double]$x, [double]$y, [double]$w, $color, [scriptblock]$item, [double]$angle = 0) {
    $g.Transform = SlotMatrix $x $y $w
    $radius = 0.11
    $shape = RoundedRect 0 0 1 1 $radius

    # A soft glow of the set's colour around the slot.
    if ($color) {
        foreach ($step in @(@(0.16, 18), @(0.11, 30), @(0.07, 50))) {
            $pen = New-Object System.Drawing.Pen ((Rgb $color $step[1])), ([single]$step[0])
            $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
            $g.DrawPath($pen, $shape)
        }
    }

    # The empty slot, then the set's tint, stronger toward the edges.
    $g.FillPath((GradientBrush (RectF 0 0 1 1) 90 @((Hex '2c313d'), (Hex '161920')) @(0.0, 1.0)), $shape)
    if ($color) {
        $tint = New-Object System.Drawing.Drawing2D.PathGradientBrush $shape
        $tint.CenterColor = Rgb $color 12
        $tint.SurroundColors = @((Rgb $color 90))
        $g.FillPath($tint, $shape)
    }

    # The item, with a shadow down and to the right.
    $shapes = & $item
    $g.Transform = SlotMatrix $x $y $w 0.025 0.035 $angle
    $shadow = Solid ($C::FromArgb(130, 0, 0, 0))
    foreach ($part in $shapes) { $g.FillPath($shadow, $part[0]) }
    $g.Transform = SlotMatrix $x $y $w 0 0 $angle
    foreach ($part in $shapes) { $g.FillPath($part[1], $part[0]) }

    # The border: the set's colour, or the plain grey of an unmarked slot.
    $g.Transform = SlotMatrix $x $y $w
    $border = 0.07
    $borderColor = if ($color) { Rgb $color } else { Hex '505665' }
    $pen = New-Object System.Drawing.Pen $borderColor, ([single]$border)
    $g.DrawPath($pen, (RoundedRect ($border / 2) ($border / 2) (1 - $border) (1 - $border) ($radius - $border / 2)))
}

# The addon's first default colours (Core.lua): red, cyan, yellow.
$red = @(1.00, 0.20, 0.20)
$cyan = @(0.15, 0.95, 0.95)
$yellow = @(1.00, 0.90, 0.10)

$margin, $gap = 0.075, 0.05
$w = (1 - 2 * $margin - $gap) / 2
$a, $b = $margin, ($margin + $w + $gap)
Slot $a $a $w $red ${function:Sword} 45
Slot $b $a $w $cyan ${function:Helm}
Slot $a $b $w $yellow ${function:Shield}
Slot $b $b $w $null ${function:Potion}
$g.Dispose()

# Scale down to the requested size.
$bmp = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
$g.DrawImage($big, (New-Object System.Drawing.Rectangle 0, 0, $Size, $Size))
$g.Dispose()
$big.Dispose()

if ($Out -match '\.tga$') {
    $lock = $bmp.LockBits((New-Object System.Drawing.Rectangle 0, 0, $Size, $Size), [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $pixels = New-Object byte[] ($lock.Stride * $Size)
    [System.Runtime.InteropServices.Marshal]::Copy($lock.Scan0, $pixels, 0, $pixels.Length)
    $stride = $lock.Stride
    $bmp.UnlockBits($lock)
    $header = New-Object byte[] 18
    $header[2] = 2                                              # uncompressed true colour
    $header[12] = $Size -band 0xFF; $header[13] = $Size -shr 8  # width
    $header[14] = $Size -band 0xFF; $header[15] = $Size -shr 8  # height
    $header[16] = 32                                            # bits per pixel
    $header[17] = 8                                             # 8 alpha bits, bottom-left origin
    $stream = [System.IO.File]::Create($Out)
    try {
        $stream.Write($header, 0, 18)
        for ($row = $Size - 1; $row -ge 0; $row--) { $stream.Write($pixels, $row * $stride, $Size * 4) }  # BGRA, bottom row first
    } finally { $stream.Dispose() }
} else {
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
}
$bmp.Dispose()
Write-Output "$Out ($Size x $Size)"
