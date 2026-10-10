$script:HtmlStyle = @'
:root {
  --bg: #f6f6f3; --surface: #ffffff; --text: #1d1d1f; --muted: #6b6b72; --border: #e2e2dd;
  --accent: #2f5bd3; --code: #f0f0ec;
  --warn-bg: #fff3d1; --warn: #7a5200; --danger-bg: #fde6e4; --danger: #b42318;
  --info-bg: #e7eefc; --info: #2346a8; --ok: #1f7a4d;
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #131315; --surface: #1c1c1f; --text: #ececef; --muted: #9a9aa3; --border: #2d2d33;
    --accent: #8ba6ff; --code: #242428;
    --warn-bg: #3a2f12; --warn: #f2c65c; --danger-bg: #3d1818; --danger: #ff8f85;
    --info-bg: #1d2a4a; --info: #a9bfff; --ok: #6fd3a0;
  }
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font: 14px/1.5 "Segoe UI", system-ui, -apple-system, sans-serif; }
.wrap { max-width: 1240px; margin: 0 auto; padding: 32px 16px 64px; }
h1 { font-size: 24px; margin: 0 0 4px; letter-spacing: -0.01em; }
.meta { color: var(--muted); margin: 0 0 24px; }
.stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; margin-bottom: 20px; }
.stat { background: var(--surface); border: 1px solid var(--border); border-radius: 10px; padding: 12px 14px; }
.stat b { display: block; font-size: 22px; font-variant-numeric: tabular-nums; }
.stat span { color: var(--muted); font-size: 13px; }
.stat.warn b { color: var(--warn); } .stat.danger b { color: var(--danger); }
.toolbar { position: sticky; top: 0; z-index: 2; display: flex; flex-wrap: wrap; gap: 8px 18px; align-items: center;
  background: var(--bg); padding: 10px 0 14px; border-bottom: 1px solid var(--border); margin-bottom: 18px; }
.toolbar input[type=search] { flex: 1 1 260px; padding: 8px 12px; border-radius: 8px; border: 1px solid var(--border);
  background: var(--surface); color: var(--text); font: inherit; }
.toolbar label { color: var(--muted); user-select: none; cursor: pointer; }
.toolbar .count { margin-left: auto; color: var(--muted); font-variant-numeric: tabular-nums; }
.item { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; margin-bottom: 14px; overflow: hidden; }
.item > header { padding: 14px 16px 10px; display: flex; flex-wrap: wrap; gap: 6px 10px; align-items: baseline; }
.item h2 { font-size: 15px; margin: 0; font-family: Consolas, "Cascadia Mono", monospace; font-weight: 600; word-break: break-all; }
.kind { color: var(--muted); font-size: 12px; }
.badge { font-size: 12px; padding: 1px 8px; border-radius: 999px; white-space: nowrap; }
.badge.warn { background: var(--warn-bg); color: var(--warn); }
.badge.danger { background: var(--danger-bg); color: var(--danger); }
.badge.info { background: var(--info-bg); color: var(--info); }
.facts { margin: 0; padding: 0 16px 10px; color: var(--muted); display: flex; flex-wrap: wrap; gap: 4px 24px; }
.facts b { color: var(--text); font-weight: 500; }
.facts .bad { color: var(--warn); }
.note { margin: 0 16px 10px; color: var(--warn); }
.error { margin: 0 16px 14px; color: var(--danger); }
.table-wrap { overflow-x: auto; }
table { width: 100%; border-collapse: collapse; }
th, td { text-align: left; padding: 7px 16px; border-top: 1px solid var(--border); vertical-align: top; }
th { font-size: 12px; font-weight: 600; color: var(--muted); text-transform: uppercase; letter-spacing: 0.04em; }
td.type { white-space: nowrap; }
tr.allow td.type { color: var(--ok); }
tr.deny td.type { color: var(--danger); font-weight: 600; }
tr.deny td { background: var(--danger-bg); }
tr.inherited td { color: var(--muted); }
tr.inherited.allow td.type { color: var(--muted); }
tr.unresolved td.who { color: var(--warn); }
.sid { display: block; font-size: 12px; color: var(--muted); font-family: Consolas, monospace; }
.detail { display: block; font-size: 12px; color: var(--muted); }
body.hide-inherited tr.inherited { display: none; }
details { border-top: 1px solid var(--border); }
summary { cursor: pointer; padding: 9px 16px; color: var(--accent); }
.sddl { display: block; margin: 0 16px 10px; padding: 10px 12px; background: var(--code); border-radius: 8px;
  font: 12px/1.6 Consolas, "Cascadia Mono", monospace; word-break: break-all; }
.sddl-table td { padding: 4px 16px; font-size: 13px; border-top: none; }
.sddl-table td.tok { font-family: Consolas, monospace; color: var(--accent); white-space: nowrap; }
.sddl-table td.lbl { color: var(--muted); white-space: nowrap; }
.sddl-table tr.ace td { padding-top: 12px; font-family: Consolas, monospace; font-weight: 600; }
[hidden] { display: none !important; }
footer { color: var(--muted); font-size: 12px; margin-top: 28px; }
'@

$script:HtmlScript = @'
(function () {
  var q = document.getElementById('q'), notable = document.getElementById('notable'),
      inh = document.getElementById('inherited'), count = document.getElementById('count'),
      items = Array.prototype.slice.call(document.querySelectorAll('.item'));
  function apply() {
    var t = q.value.trim().toLowerCase(), n = 0;
    items.forEach(function (el) {
      var show = (!notable.checked || el.classList.contains('notable')) && (!t || el.getAttribute('data-search').indexOf(t) >= 0);
      el.hidden = !show; if (show) n++;
    });
    count.textContent = n + ' von ' + items.length + ' Objekten';
    document.body.classList.toggle('hide-inherited', inh.checked);
  }
  q.addEventListener('input', apply); notable.addEventListener('change', apply); inh.addEventListener('change', apply);
  apply();
})();
'@

function ConvertTo-NtfsHtml {
    [CmdletBinding()]
    param([object[]]$Items, [string]$Title)

    $e = { [System.Net.WebUtility]::HtmlEncode([string]$args[0]) }
    $sb = [System.Text.StringBuilder]::new()

    $allAces = @($Items | ForEach-Object { $_.Aces })
    $stats = @(
        @{ Label = 'Objekte'; Value = $Items.Count; Class = '' }
        @{ Label = 'Vererbung deaktiviert'; Value = @($Items | Where-Object { $_.InheritanceEnabled -eq $false }).Count; Class = 'warn' }
        @{ Label = 'Explizite Einträge'; Value = @($allAces | Where-Object { -not $_.Inherited }).Count; Class = '' }
        @{ Label = 'Verweigern-Einträge'; Value = @($allAces | Where-Object { $_.IsDeny -and -not $_.Inherited }).Count; Class = 'danger' }
        @{ Label = 'Nicht auflösbare SIDs'; Value = @($allAces | Where-Object { -not $_.Resolved } | ForEach-Object { $_.Sid } | Sort-Object -Unique).Count; Class = 'warn' }
        @{ Label = 'Nicht lesbar'; Value = @($Items | Where-Object { $_.Error }).Count; Class = 'danger' }
    )

    $null = $sb.AppendLine('<!doctype html><html lang="de"><head><meta charset="utf-8">')
    $null = $sb.AppendLine('<meta name="viewport" content="width=device-width, initial-scale=1">')
    $null = $sb.AppendLine("<title>$(& $e $Title)</title><style>$script:HtmlStyle</style></head><body><div class=""wrap"">")
    $null = $sb.AppendLine("<h1>$(& $e $Title)</h1>")
    $null = $sb.AppendLine("<p class=""meta"">Erstellt am $(Get-Date -Format 'dd.MM.yyyy HH:mm') auf $(& $e $env:COMPUTERNAME) von $(& $e "$([Environment]::UserDomainName)\$([Environment]::UserName)")</p>")

    $null = $sb.AppendLine('<section class="stats">')
    foreach ($s in $stats) {
        $cls = if ($s.Value -gt 0 -and $s.Class) { "stat $($s.Class)" } else { 'stat' }
        $null = $sb.AppendLine("<div class=""$cls""><b>$($s.Value)</b><span>$(& $e $s.Label)</span></div>")
    }
    $null = $sb.AppendLine('</section>')

    $null = $sb.AppendLine('<div class="toolbar"><input id="q" type="search" placeholder="Filtern nach Pfad, Konto, Recht …" autocomplete="off">')
    $null = $sb.AppendLine('<label><input id="notable" type="checkbox"> Nur Auffälligkeiten</label>')
    $null = $sb.AppendLine('<label><input id="inherited" type="checkbox"> Geerbte Einträge ausblenden</label>')
    $null = $sb.AppendLine('<span class="count" id="count"></span></div><main>')

    foreach ($item in $Items) {
        $search = (@($item.Path, $item.Owner) + @($item.Aces | ForEach-Object { $_.Principal, $_.Sid, $_.Rights, $_.Type })) -join ' '
        $cls = if (Test-NtfsNotable $item) { 'item notable' } else { 'item' }
        $null = $sb.AppendLine("<article class=""$cls"" data-search=""$(& $e $search.ToLowerInvariant())""><header>")
        $null = $sb.AppendLine("<h2>$(& $e $(if ($item.Path) { $item.Path } else { '(SDDL)' }))</h2>")
        if ($item.ItemType) { $null = $sb.Append("<span class=""kind"">$(& $e $item.ItemType)</span>") }

        $badges = @()
        if ($item.Error) { $badges += '<span class="badge danger">Nicht lesbar</span>' }
        if ($item.NullDacl) { $badges += '<span class="badge danger">NULL-DACL</span>' }
        if ($item.InheritanceEnabled -eq $false) { $badges += '<span class="badge warn">Vererbung deaktiviert</span>' }
        if ($item.IsCanonical -eq $false) { $badges += '<span class="badge warn">Nicht kanonisch</span>' }
        if (@($item.Aces | Where-Object { -not $_.Resolved }).Count) { $badges += '<span class="badge warn">Verwaiste SID</span>' }
        if ($item.ExplicitCount) { $badges += "<span class=""badge info"">$($item.ExplicitCount) explizit</span>" }
        $null = $sb.AppendLine(($badges -join '') + '</header>')

        if ($item.Error) {
            $null = $sb.AppendLine("<p class=""error"">$(& $e $item.Error)</p></article>")
            continue
        }

        $ownerCls = if ($item.OwnerResolved) { '' } else { ' class="bad"' }
        $inhText = if ($item.InheritanceEnabled) { 'aktiv' } else { '<b class="bad">deaktiviert</b>' }
        $null = $sb.AppendLine("<p class=""facts""><span>Besitzer <b$ownerCls>$(& $e $item.Owner)</b></span><span>Vererbung $inhText</span><span>$($item.AceCount) Einträge</span></p>")
        if ($item.Note) { $null = $sb.AppendLine("<p class=""note"">$(& $e $item.Note)</p>") }

        $null = $sb.AppendLine('<div class="table-wrap"><table><thead><tr><th>Typ</th><th>Konto</th><th>Rechte</th><th>Gilt für</th><th>Herkunft</th></tr></thead><tbody>')
        foreach ($ace in $item.Aces) {
            $rc = @(if ($ace.IsDeny) { 'deny' } else { 'allow' })
            if ($ace.Inherited) { $rc += 'inherited' }
            if (-not $ace.Resolved) { $rc += 'unresolved' }
            $sidLine = if (-not $ace.Resolved) { '<span class="sid">nicht auflösbar - verwaiste SID?</span>' }
            elseif ($ace.Principal -like "*$($ace.Sid)*") { '' }
            else { "<span class=""sid"">$(& $e $ace.Sid)</span>" }
            $detail = if ($ace.Rights -like '*Spezial*') { "<span class=""detail"">$(& $e $ace.RightsDetail)</span>" } else { '' }
            $origin = if ($ace.Inherited) { 'geerbt' } else { 'explizit' }
            $null = $sb.AppendLine(("<tr class=""{0}""><td class=""type"">{1}</td><td class=""who"">{2}{3}</td><td title=""{4}"">{5}{6}</td><td>{7}</td><td>{8}</td></tr>" -f
                    ($rc -join ' '), (& $e $ace.Type), (& $e $ace.Principal), $sidLine, (& $e "$($ace.AccessMask): $($ace.RightsDetail)"),
                    (& $e $ace.Rights), $detail, (& $e $ace.AppliesTo), $origin))
        }
        $null = $sb.AppendLine('</tbody></table></div>')

        if ($item.AuditAces) {
            $null = $sb.AppendLine('<div class="table-wrap"><table><thead><tr><th>Überwachung</th><th>Konto</th><th>Rechte</th><th>Gilt für</th><th>Herkunft</th></tr></thead><tbody>')
            foreach ($ace in $item.AuditAces) {
                $origin = if ($ace.Inherited) { 'geerbt' } else { 'explizit' }
                $null = $sb.AppendLine(("<tr><td class=""type"">{0}</td><td>{1}</td><td>{2}</td><td>{3}</td><td>{4}</td></tr>" -f
                        (& $e $ace.Type), (& $e $ace.Principal), (& $e $ace.Rights), (& $e $ace.AppliesTo), $origin))
            }
            $null = $sb.AppendLine('</tbody></table></div>')
        }

        $b = Get-NtfsSddlBreakdown $item
        $null = $sb.AppendLine("<details><summary>SDDL aufschlüsseln</summary><code class=""sddl"">$(& $e $item.Sddl)</code><div class=""table-wrap""><table class=""sddl-table""><tbody>")
        foreach ($h in $b.Header) {
            $null = $sb.AppendLine("<tr><td class=""tok"">$(& $e $h.Token)</td><td class=""lbl"">$(& $e $h.Label)</td><td>$(& $e $h.Meaning)</td></tr>")
        }
        foreach ($a in $b.Aces) {
            $null = $sb.AppendLine("<tr class=""ace""><td class=""tok"" colspan=""3"">#$($a.Index) $(& $e $a.Raw)</td></tr>")
            foreach ($p in $a.Parts) {
                $null = $sb.AppendLine("<tr><td class=""tok"">$(& $e $p.Token)</td><td class=""lbl"">$(& $e $p.Label)</td><td>$(& $e $p.Meaning)</td></tr>")
            }
        }
        $null = $sb.AppendLine('</tbody></table></div></details></article>')
    }

    $null = $sb.AppendLine("</main><footer>Erzeugt mit dem PowerShell-Modul NtfsPermissions</footer></div><script>$script:HtmlScript</script></body></html>")
    $sb.ToString()
}
