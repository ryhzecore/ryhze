$ErrorActionPreference = 'Stop'
$fixtureFolder = Join-Path (Split-Path $PSScriptRoot -Parent) '.private\qa\game-library'
New-Item -ItemType Directory -Force -Path $fixtureFolder | Out-Null
$fixturePath = Join-Path $fixtureFolder 'RyhzeTestGame.exe'
if (!(Test-Path -LiteralPath $fixturePath)) {
  Add-Type -TypeDefinition @'
using System;
using System.Windows.Forms;
using System.Drawing;
public class RyhzeTestGame {
  [STAThread] public static void Main() {
    var form = new Form();
    form.Text = "Ryhze game library test fixture";
    form.Width = 460; form.Height = 220;
    form.BackColor = Color.FromArgb(9,9,12);
    var label = new Label(); label.Dock = DockStyle.Fill;
    label.TextAlign = ContentAlignment.MiddleCenter;
    label.ForeColor = Color.White;
    label.Text = "Ryhze launcher verification\nThis test window closes automatically.";
    form.Controls.Add(label);
    var timer = new Timer(); timer.Interval = 120000;
    timer.Tick += (sender, args) => form.Close(); timer.Start();
    Application.Run(form);
  }
}
'@ -ReferencedAssemblies System.Windows.Forms,System.Drawing -OutputAssembly $fixturePath -OutputType WindowsApplication
}
Write-Output $fixturePath
