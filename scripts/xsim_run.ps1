param(
  [Parameter(Mandatory=$true)][string]$Tb
)

New-Item -Force -ItemType Directory build | Out-Null

# Collect sources recursively
$srcs = Get-ChildItem -Recurse -File src -Include *.sv,*.v | ForEach-Object { $_.FullName }

xvlog --sv $srcs "test/$Tb.sv"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xelab -debug typical $Tb -s $Tb
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

xsim -R $Tb
exit $LASTEXITCODE
