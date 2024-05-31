#!/usr/bin/pwsh

$root = "$PSScriptRoot\app\src\main\res\xml"
$appfilter = "$root\appfilter.xml"

Copy-Item  $appfilter "$root\..\..\assets\appfilter.xml"

$appmap = "$root\appmap.xml"
@"
<?xml version="1.0" encoding="UTF-8"?>
<appmap>
"@ > $appmap

$theme = "$root\theme_resources.xml"
@"
<?xml version="1.0" encoding="UTF-8"?>
<Theme version="1">
    <Label value="Paper" />
    <Wallpaper image="wallpaper_1" />
    <LockScreenWallpaper image="wallpaper_1" />
    <ThemePreview image="preview_1" />
    <ThemePreviewWork image="preview_1" />
    <ThemePreviewMenu image="preview_1" />
    <DockMenuAppIcon selector="drawer" />
"@ > $theme

$drawable = "$root\drawable.xml"
@"
<?xml version="1.0" encoding="utf-8"?>
<resources>

    <version>1</version>

    <category title="All" />
"@ > $drawable

$drawable_set = [System.Collections.Generic.HashSet[string]]::new()
$activity_set = [System.Collections.Generic.HashSet[string]]::new()

[xml] (Get-Content $appfilter) `
| Select-Object -ExpandProperty ChildNodes `
| Where-Object -Property Name -EQ -Value resources `
| Select-Object -First 1 `
| Select-Object -ExpandProperty ChildNodes `
| ForEach-Object {
    if ($_.Name -eq 'item') {
        $i = $_.component.IndexOf('{')
        $j = $_.component.IndexOf('/')
        $k = $_.component.IndexOf('}')

        if ($prev -ne $_.drawable) {
            $prev = $_.drawable
            '' >> $appmap
            '' >> $theme
        }

        $activity = $_.component.Substring($j + 1, $k - $j - 1)
        if ($activity_set.Add($activity)) {
            @"
    <item
        class="$activity"
        name="$($_.drawable)" />
"@ >> $appmap
        }

        @"
    <AppIcon
        name="$($_.component.Substring($i + 1, $k - $i - 1))"
        image="$($_.drawable)" />
"@ >> $theme

        if ($drawable_set.Add($_.drawable)) {
            "    <item drawable=`"$($_.drawable)`" />" >> $drawable
        }
    }
}

@"

</appmap>
"@ >> $appmap

@"

</Theme>
"@ >>$theme

@"

</resources>
"@ >> $drawable

$drawable_diff = git diff $drawable
@"
<?xml version="1.0" encoding="utf-8"?>
<resources>

    <version>1</version>

    <category title="Added" />
"@ > $drawable
$drawable_diff | ForEach-Object {
    if ($_ -match "^\+\s+<item drawable=`"(.+?)`" />") {
        "    <item drawable=`"$($Matches[1])`" />" >> $drawable
    }
}

@"

    <category title="Updated" />

    <category title="All" />
"@ >> $drawable
$drawable_set | ForEach-Object {
    "    <item drawable=`"$_`" />" >> $drawable
}
@"

</resources>
"@ >> $drawable

Write-Host 'Waiting for editor to close...'
code --wait $drawable

$category = ''

$drawable_assets = "$root\..\..\assets\drawable.xml"
@"
<?xml version="1.0" encoding="utf-8"?>
<resources>

    <version>1</version>
"@ > $drawable_assets

$icon_pack = "$root\..\values\icon_pack.xml"
$previews = [xml] (Get-Content $icon_pack) `
| Select-Object -ExpandProperty ChildNodes `
| Where-Object -Property Name -EQ -Value resources `
| Select-Object -First 1 `
| Select-Object -ExpandProperty ChildNodes `
| Where-Object -Property name -EQ -Value icons_preview `
| Select-Object -First 1 `
| Select-Object -ExpandProperty ChildNodes `
| Select-Object -ExpandProperty InnerText

@"
<?xml version="1.0" encoding="utf-8"?><!--suppress CheckTagEmptyBody -->
<resources xmlns:tools="http://schemas.android.com/tools" tools:ignore="ExtraTranslation">

    <string-array name="icons_preview">
"@ > $icon_pack
$previews | ForEach-Object {
    "        <item>$_</item>" >> $icon_pack
}
@"
    </string-array>

    <string-array name="icon_filters">
"@ >> $icon_pack

$drawable_items = [xml] (Get-Content $drawable) `
| Select-Object -ExpandProperty ChildNodes `
| Where-Object -Property Name -EQ -Value resources `
| Select-Object -First 1 `
| Select-Object -ExpandProperty ChildNodes

$drawable_items | ForEach-Object {
    if ($_.Name -eq 'category') {
        $category = $_.title
        if ($category -ne 'All') {
            @"

    <category title="$category" />
"@ >> $drawable_assets
        }
        "        <item>$($category.ToLowerInvariant())</item>" >> $icon_pack
    } elseif ($_.Name -eq 'item') {
        if ($category -ne 'All') {
            "    <item drawable=`"$($_.drawable)`" />" >> $drawable_assets
        }
    }
}

$drawable_items | ForEach-Object {
    if ($_.Name -eq 'category') {
        $category = $_.title
        @"
    </string-array>

    <string-array name="$($category.ToLowerInvariant())">
"@ >> $icon_pack
    } elseif ($_.Name -eq 'item') {
        "        <item>$($_.drawable)</item>" >> $icon_pack
    }
}

"    </string-array>" >> $icon_pack

@"

</resources>
"@ >> $drawable_assets

@"

</resources>
"@ >> $icon_pack
