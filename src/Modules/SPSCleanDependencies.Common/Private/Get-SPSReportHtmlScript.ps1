function Get-SPSReportHtmlScript {
    <#
        .SYNOPSIS
        Returns the vanilla-JavaScript block that renders the interactive per-category tables.

        .DESCRIPTION
        Reads a single JSON payload (embedded in a <script type="application/json"
        id="spsReportData"> element) describing one or more sections. Each section has
        an id, a list of columns and a list of rows. For every section the script wires
        a per-section search box (filter) and clickable column headers (sort) against
        the matching <table> rendered by Export-SPSCleanDependenciesReport. No external
        dependency (works offline on a SharePoint server).
    #>
    [CmdletBinding()]
    [OutputType([System.String])]
    param ()

    $js = @'
(function(){
  var node = document.getElementById('spsReportData');
  if (!node) { return; }
  var data = JSON.parse(node.textContent || node.innerText);
  var sections = data.sections || [];

  sections.forEach(function(section){
    var cols = section.columns || [];
    var rows = section.rows || [];
    var sortField = null, sortDir = 1, view = rows;
    var search = document.getElementById('search-' + section.id);
    var thead = document.getElementById('thead-' + section.id);
    var tbody = document.getElementById('tbody-' + section.id);
    var info = document.getElementById('info-' + section.id);
    if (!thead || !tbody) { return; }

    function isNum(c){ return c.type === 'num'; }

    function buildHead(){
      var tr = document.createElement('tr');
      cols.forEach(function(c){
        var th = document.createElement('th');
        if (isNum(c)) { th.className = 'num'; }
        th.textContent = c.label + '  \u2195';
        th.addEventListener('click', function(){
          if (sortField === c.field) { sortDir = -sortDir; } else { sortField = c.field; sortDir = 1; }
          applySort(); render();
        });
        tr.appendChild(th);
      });
      thead.appendChild(tr);
    }

    function applyFilter(){
      var q = (search && search.value || '').trim().toLowerCase();
      if (!q) { view = rows; }
      else {
        view = rows.filter(function(r){
          return cols.some(function(c){
            var v = r[c.field];
            return v != null && String(v).toLowerCase().indexOf(q) !== -1;
          });
        });
      }
    }

    function applySort(){
      if (!sortField) { return; }
      var col = null;
      cols.forEach(function(c){ if (c.field === sortField) { col = c; } });
      var numeric = col && isNum(col);
      view = view.slice().sort(function(a,b){
        var x = a[sortField], y = b[sortField];
        if (numeric) {
          x = parseFloat(x); y = parseFloat(y);
          if (isNaN(x)) { x = -Infinity; } if (isNaN(y)) { y = -Infinity; }
          return (x - y) * sortDir;
        }
        x = x == null ? '' : String(x).toLowerCase();
        y = y == null ? '' : String(y).toLowerCase();
        if (x < y) { return -1 * sortDir; }
        if (x > y) { return 1 * sortDir; }
        return 0;
      });
    }

    function render(){
      tbody.innerHTML = '';
      view.forEach(function(r){
        var tr = document.createElement('tr');
        cols.forEach(function(c){
          var td = document.createElement('td');
          if (isNum(c)) { td.className = 'num'; }
          td.textContent = r[c.field] == null ? '' : r[c.field];
          tr.appendChild(td);
        });
        tbody.appendChild(tr);
      });
      if (info) { info.textContent = view.length + ' / ' + rows.length + ' rows'; }
    }

    if (search) {
      search.addEventListener('input', function(){ applyFilter(); applySort(); render(); });
    }
    buildHead(); render();
  });
})();
'@

    return "<script>$js</script>"
}
