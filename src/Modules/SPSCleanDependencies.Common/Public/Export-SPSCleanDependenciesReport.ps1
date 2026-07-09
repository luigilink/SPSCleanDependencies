function Export-SPSCleanDependenciesReport {
    <#
        .SYNOPSIS
        Generates a self-contained HTML report from a SPSCleanDependencies results JSON.

        .DESCRIPTION
        Export-SPSCleanDependenciesReport renders the results produced by
        Get-SPSMissingServerDependencies (the Results\<FileName>.json audit file) as a
        single, dependency-free HTML file (no CDN, works offline on a SharePoint server).

        The report shows one summary card per dependency category (count of items found)
        and, for every non-empty category, a filterable / sortable table of the items
        with their identifying fields. When the audit found nothing, the report renders a
        clean "no missing dependencies" state.

        The data can be supplied either as a file (-InputFile, the JSON results) or as an
        already-parsed object (-InputObject). Returns the path of the report written.

        .PARAMETER InputFile
        Path of the results JSON file to read.

        .PARAMETER InputObject
        An already-parsed results object (as returned by ConvertFrom-Json).

        .PARAMETER OutputFile
        Destination path of the generated .html file.

        .PARAMETER Title
        Heading shown at the top of the report. Defaults to a generic title.

        .PARAMETER FarmName
        Farm / file label shown in the metadata line (e.g. CONTOSO-PROD-SPSE).

        .PARAMETER Version
        SPSCleanDependencies version stamped in the report footer. Defaults to the
        SPSCleanDependencies.Common module version.

        .EXAMPLE
        Export-SPSCleanDependenciesReport -InputFile $json -OutputFile $html -FarmName 'CONTOSO-PROD-SPSE'
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByFile')]
    [OutputType([System.String])]
    param
    (
        [Parameter(Mandatory = $true, ParameterSetName = 'ByFile')]
        [System.String]
        $InputFile,

        [Parameter(Mandatory = $true, ParameterSetName = 'ByObject')]
        $InputObject,

        [Parameter(Mandatory = $true)]
        [System.String]
        $OutputFile,

        [Parameter()]
        [System.String]
        $Title,

        [Parameter()]
        [System.String]
        $FarmName,

        [Parameter()]
        [System.String]
        $Version
    )

    # ---- Load the results ---------------------------------------------------------
    if ($PSCmdlet.ParameterSetName -eq 'ByFile') {
        if (-not (Test-Path -Path $InputFile)) {
            throw "Export-SPSCleanDependenciesReport: input file not found: $InputFile"
        }
        $raw = Get-Content -Path $InputFile -Raw -Encoding UTF8
        $results = if ([string]::IsNullOrWhiteSpace($raw)) { $null } else { $raw | ConvertFrom-Json }
    }
    else {
        $results = $InputObject
    }

    if ([string]::IsNullOrEmpty($Title)) { $Title = 'SPSCleanDependencies - Missing Server Dependencies Report' }

    if ([string]::IsNullOrEmpty($Version)) {
        $moduleVersion = (Get-Module -Name SPSCleanDependencies.Common -ErrorAction SilentlyContinue).Version
        $Version = if ($null -ne $moduleVersion) { $moduleVersion.ToString() } else { 'unknown' }
    }

    # ---- Category metadata (JSON key -> label + table columns) --------------------
    $categories = @(
        [PSCustomObject]@{ Key = 'MissingFeature'; Label = 'Missing Features'; Columns = @(
                @{ field = 'Database'; label = 'Database'; type = 'text' }
                @{ field = 'FeatureID'; label = 'Feature ID'; type = 'text' }
                @{ field = 'SiteID'; label = 'Site ID'; type = 'text' }
                @{ field = 'Path'; label = 'Path'; type = 'text' }
            ) }
        [PSCustomObject]@{ Key = 'MissingWebPart'; Label = 'Missing WebParts'; Columns = @(
                @{ field = 'Database'; label = 'Database'; type = 'text' }
                @{ field = 'WebPartID'; label = 'WebPart ID'; type = 'text' }
                @{ field = 'ClassName'; label = 'Class'; type = 'text' }
                @{ field = 'SiteID'; label = 'Site ID'; type = 'text' }
                @{ field = 'WebID'; label = 'Web ID'; type = 'text' }
                @{ field = 'DirName'; label = 'Dir'; type = 'text' }
                @{ field = 'LeafName'; label = 'Page'; type = 'text' }
            ) }
        [PSCustomObject]@{ Key = 'MissingSetupFile'; Label = 'Missing Setup Files'; Columns = @(
                @{ field = 'Database'; label = 'Database'; type = 'text' }
                @{ field = 'SetupPath'; label = 'Setup Path'; type = 'text' }
                @{ field = 'FileID'; label = 'File ID'; type = 'text' }
                @{ field = 'SiteID'; label = 'Site ID'; type = 'text' }
                @{ field = 'WebID'; label = 'Web ID'; type = 'text' }
            ) }
        [PSCustomObject]@{ Key = 'MissingAssembly'; Label = 'Missing Assemblies'; Columns = @(
                @{ field = 'Database'; label = 'Database'; type = 'text' }
                @{ field = 'AssemblyInfo'; label = 'Assembly'; type = 'text' }
                @{ field = 'AssemblyID'; label = 'Assembly ID'; type = 'text' }
                @{ field = 'HostType'; label = 'Host Type'; type = 'text' }
                @{ field = 'HostID'; label = 'Host ID'; type = 'text' }
                @{ field = 'SiteID'; label = 'Site ID'; type = 'text' }
                @{ field = 'WebID'; label = 'Web ID'; type = 'text' }
            ) }
        [PSCustomObject]@{ Key = 'Configuration'; Label = 'Configuration (Classic Auth Admins)'; Columns = @(
                @{ field = 'Database'; label = 'Database'; type = 'text' }
                @{ field = 'SiteID'; label = 'Site ID'; type = 'text' }
                @{ field = 'Login'; label = 'Login'; type = 'text' }
            ) }
        [PSCustomObject]@{ Key = 'MissingSiteDefinition'; Label = 'Missing Site Definitions (audit only)'; Columns = @(
                @{ field = 'Database'; label = 'Database'; type = 'text' }
                @{ field = 'Message'; label = 'Message'; type = 'text' }
                @{ field = 'Remedy'; label = 'Remedy'; type = 'text' }
            ) }
        [PSCustomObject]@{ Key = 'SiteOrphan'; Label = 'Orphaned Sites'; Columns = @(
                @{ field = 'Database'; label = 'Database'; type = 'text' }
                @{ field = 'SiteID'; label = 'Site ID'; type = 'text' }
            ) }
    )

    # ---- Build cards, sections and JSON payload -----------------------------------
    $cards = @()
    $sectionsHtml = ''
    $payloadSections = @()
    $totalItems = 0

    foreach ($category in $categories) {
        $items = @()
        if ($null -ne $results -and ($results.PSObject.Properties.Name -contains $category.Key)) {
            $items = @($results.$($category.Key) | Where-Object { $null -ne $_ })
        }
        $count = $items.Count
        $totalItems += $count

        $tone = if ($count -eq 0) { 'clean' } else { 'alert' }
        $cards += (Get-SPSReportCardHtml -Value $count -Label $category.Label -Tone $tone)

        if ($count -eq 0) { continue }

        $sectionId = $category.Key
        $rows = foreach ($item in $items) {
            $ordered = [ordered]@{}
            foreach ($col in $category.Columns) {
                $ordered[$col.field] = "$($item.$($col.field))"
            }
            [PSCustomObject]$ordered
        }

        $payloadSections += [ordered]@{
            id      = $sectionId
            columns = $category.Columns
            rows    = @($rows)
        }

        $encLabel = ConvertTo-SPSHtmlEncoded -Value $category.Label
        $sectionsHtml += "<h2>$encLabel <span style=`"color:#666;font-weight:400;font-size:13px`">($count)</span></h2>" +
        "<div class=`"controls`"><input id=`"search-$sectionId`" class=`"search`" placeholder=`"Filter...`"><div class=`"pager`"><span id=`"info-$sectionId`"></span></div></div>" +
        "<table><thead id=`"thead-$sectionId`"></thead><tbody id=`"tbody-$sectionId`"></tbody></table>"
    }

    $payload = [ordered]@{ sections = @($payloadSections) }
    $json = $payload | ConvertTo-Json -Depth 6 -Compress
    # Neutralize any sequence that could break out of the <script> block
    $json = $json -replace '<', '\u003c' -replace '>', '\u003e' -replace '&', '\u0026'

    # ---- Metadata -----------------------------------------------------------------
    $encTitle = ConvertTo-SPSHtmlEncoded -Value $Title
    $encFarm = ConvertTo-SPSHtmlEncoded -Value $FarmName
    $encVersion = ConvertTo-SPSHtmlEncoded -Value $Version
    $generated = Get-Date -Format 'yyyy-MM-dd HH:mm'

    $metaParts = @()
    if (-not [string]::IsNullOrEmpty($encFarm)) { $metaParts += "Farm: $encFarm" }
    $metaParts += "Generated: $generated"
    $metaParts += "SPSCleanDependencies $encVersion"
    $metaLine = $metaParts -join ' &middot; '

    $totalTone = if ($totalItems -eq 0) { 'clean' } else { 'alert' }
    $totalCard = Get-SPSReportCardHtml -Value $totalItems -Label 'Total items' -Tone $totalTone
    $summaryInner = "<div class=`"cards`">$totalCard$($cards -join '')</div>"

    $emptyNote = if ($totalItems -eq 0) {
        '<div class="empty">No missing server side dependencies were found. Nothing to clean.</div>'
    }
    else { '' }

    # ---- Assemble the document ----------------------------------------------------
    $html = (Get-SPSReportHtmlHead -Title $encTitle) +
    "<h1>$encTitle</h1>" +
    "<div class=`"meta`">$metaLine</div>" +
    "<div class=`"summary`"><h3 style=`"margin-top:0`">Summary</h3>$summaryInner</div>" +
    $emptyNote +
    $sectionsHtml +
    "<div class=`"footer`">Generated by SPSCleanDependencies $encVersion. Back up your content databases and review this report before running the script with the -Clean switch.</div>" +
    "<script type=`"application/json`" id=`"spsReportData`">$json</script>" +
    (Get-SPSReportHtmlScript) +
    '</body></html>'

    # ---- Atomic write -------------------------------------------------------------
    $outDir = Split-Path -Path $OutputFile -Parent
    if (-not [string]::IsNullOrEmpty($outDir) -and -not (Test-Path -Path $outDir)) {
        $null = New-Item -Path $outDir -ItemType Directory -Force
    }

    $encoding = [System.Text.UTF8Encoding]::new($true)
    $tmpPath = '{0}.tmp.{1}' -f $OutputFile, ([guid]::NewGuid().ToString('N'))
    [System.IO.File]::WriteAllText($tmpPath, $html, $encoding)
    Move-Item -Path $tmpPath -Destination $OutputFile -Force

    return $OutputFile
}
