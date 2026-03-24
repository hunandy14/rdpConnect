#Requires -Version 5.1

<#
.SYNOPSIS
    WPF GUI for managing RDP connections.

.DESCRIPTION
    Displays a modern WPF window with categorized server list,
    multiple accounts per host, search filtering, and drag-drop reordering.
    Press F5 to reload XAML and data without restarting.

.PARAMETER Path
    Path to rdpList.json. Auto-detected if not specified.

.EXAMPLE
    Show-RdpManager

.EXAMPLE
    Show-RdpManager -Path 'C:\Servers\rdpList.json'
#>
function Show-RdpManager {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]$Path
    )

    # Verify STA thread (required for WPF)
    if ([Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') {
        throw "Show-RdpManager requires STA thread. Use: powershell.exe -STA"
    }

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase

    # Drag adorner (C# class for smooth ghost following cursor)
    if (-not ([System.Management.Automation.PSTypeName]'RdpDragAdorner').Type) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Documents;
using System.Windows.Media;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;

public class RdpDragAdorner : Adorner
{
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool GetCursorPos(out POINT pt);

    [StructLayout(LayoutKind.Sequential)]
    struct POINT { public int X, Y; }

    private ImageSource _image;
    private double _width, _height, _fixedX, _mouseOffsetY;
    private double _currentY;

    public RdpDragAdorner(UIElement adornerParent, FrameworkElement source, double mouseOffsetY)
        : base(adornerParent)
    {
        IsHitTestVisible = false;
        _width = source.ActualWidth;
        _height = source.ActualHeight;
        _mouseOffsetY = mouseOffsetY;

        // Fixed X = element's left edge relative to adorner parent
        Point pos = source.TranslatePoint(new Point(0, 0), adornerParent);
        _fixedX = pos.X;
        _currentY = pos.Y;

        // Render element to bitmap (snapshot before opacity change)
        PresentationSource ps = PresentationSource.FromVisual(adornerParent);
        double dpiX = 96;
        double dpiY = 96;
        if (ps != null && ps.CompositionTarget != null)
        {
            dpiX = 96.0 * ps.CompositionTarget.TransformToDevice.M11;
            dpiY = 96.0 * ps.CompositionTarget.TransformToDevice.M22;
        }
        DrawingVisual dv = new DrawingVisual();
        using (DrawingContext dc = dv.RenderOpen())
        {
            VisualBrush vb = new VisualBrush(source);
            vb.Stretch = Stretch.None;
            dc.DrawRectangle(vb, null, new Rect(0, 0, _width, _height));
        }
        RenderTargetBitmap bmp = new RenderTargetBitmap(
            (int)Math.Ceiling(_width * dpiX / 96.0),
            (int)Math.Ceiling(_height * dpiY / 96.0),
            dpiX, dpiY, PixelFormats.Pbgra32);
        bmp.Render(dv);
        _image = bmp;
    }

    public void UpdatePosition()
    {
        POINT pt;
        GetCursorPos(out pt);
        Point screenPt = new Point(pt.X, pt.Y);
        Point localPt = this.PointFromScreen(screenPt);
        _currentY = localPt.Y - _mouseOffsetY;
        InvalidateVisual();
    }

    protected override void OnRender(DrawingContext dc)
    {
        Rect rect = new Rect(_fixedX, _currentY, _width, _height);
        // Soft shadow
        dc.PushOpacity(0.15);
        dc.DrawImage(_image, new Rect(_fixedX + 4, _currentY + 4, _width, _height));
        dc.Pop();
        // Ghost image
        dc.PushOpacity(0.88);
        dc.DrawImage(_image, rect);
        dc.Pop();
        // Blue border
        dc.DrawRectangle(null,
            new Pen(new SolidColorBrush(Color.FromRgb(0, 120, 212)), 1.5),
            new Rect(_fixedX - 0.5, _currentY - 0.5, _width + 1, _height + 1));
    }
}
'@ -ReferencedAssemblies PresentationCore, PresentationFramework, WindowsBase, System.Xaml
    }

    # --- Resolve paths ---
    $paths = Get-RdpDataPath -BasePath $(if ($Path) { Split-Path $Path -Parent } else { $null })
    if ($Path) { $paths.DataPath = $Path }

    if (-not (Test-Path $paths.DataPath)) {
        $examplePath = Join-Path $paths.BasePath 'rdpList.example.json'
        if (Test-Path $examplePath) {
            Copy-Item $examplePath $paths.DataPath
            Write-Host "Created rdpList.json from example file." -ForegroundColor Cyan
        }
        else {
            throw "RDP data file not found: $($paths.DataPath)`nCreate it or place rdpList.example.json in the same directory."
        }
    }

    $script:dataPath = $paths.DataPath
    $script:settingsPath = $paths.SettingsPath

    # XAML directory (src/Resources relative to src/Public)
    $xamlDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'Resources'

    # Helper: load XAML from file and return WPF window
    function Import-Xaml {
        param([string]$XamlPath)
        $content = Get-Content $XamlPath -Raw -Encoding UTF8
        $content = $content -replace 'x:Class="[^"]*"', ''
        [xml]$xml = $content
        $reader = [System.Xml.XmlNodeReader]::new($xml)
        return [System.Windows.Markup.XamlReader]::Load($reader)
    }

    # === Reload loop: F5 rebuilds window from XAML + re-reads data ===
    $script:reloadRequested = $true

    while ($script:reloadRequested) {
        $script:reloadRequested = $false

        # --- Load / reload data ---
        $script:rdpData = Import-RdpData -Path $script:dataPath
        $script:rdpSettings = Import-RdpSettings -Path $script:settingsPath

        # --- Load main XAML ---
        $window = Import-Xaml (Join-Path $xamlDir 'RdpManager.xaml')

        # --- Get UI elements ---
        $txtSearch = $window.FindName('TxtSearch')
        $txtSearchPlaceholder = $window.FindName('TxtSearchPlaceholder')
        $panelCategories = $window.FindName('PanelCategories')
        $rbWindowed = $window.FindName('RbWindowed')
        $rbFullScreen = $window.FindName('RbFullScreen')
        $btnAddHost = $window.FindName('BtnAddHost')
        $btnCategoryMgr = $window.FindName('BtnCategoryMgr')
        $btnEditJson = $window.FindName('BtnEditJson')
        $txtStatusBar = $window.FindName('TxtStatusBar')

        # --- Status bar hint ---
        if ($txtStatusBar) { $txtStatusBar.Text = 'F5 Reload' }

        # --- Restore settings ---
        $w = $script:rdpSettings.window
        if ($w.width -gt 0) { $window.Width = $w.width }
        if ($w.height -gt 0) { $window.Height = $w.height }
        if ($w.left -ge 0 -and $w.top -ge 0) {
            $window.WindowStartupLocation = 'Manual'
            $window.Left = $w.left
            $window.Top = $w.top
        }

        if ($script:rdpSettings.connectionMode -eq 'fullscreen') {
            $rbFullScreen.IsChecked = $true
        }
        else {
            $rbWindowed.IsChecked = $true
        }

        # --- Drag-drop state ---
        $script:dragState = @{
            Active       = $false
            Source       = $null
            StartPos     = $null
            Type         = $null
            CatName      = $null
            HostIndex    = -1
            CatIndex     = -1
            CurrentIndex = -1   # Tracks live position during drag
        }

        # Drag ghost adorner (AdornerLayer approach — proven WPF pattern)
        $script:dragAdorner = $null
        $script:dragAdornerLayer = $null
        $script:dragSourceElement = $null

        function Show-DragAdorner {
            param($SourceElement)
            $script:dragSourceElement = $SourceElement

            # Get adorner layer from window content
            $script:dragAdornerLayer = [System.Windows.Documents.AdornerLayer]::GetAdornerLayer($window.Content)
            if (-not $script:dragAdornerLayer) { return }

            # Calculate mouse Y offset within the element
            $mouseInElement = [System.Windows.Input.Mouse]::GetPosition($SourceElement)
            $mouseOffsetY = $mouseInElement.Y

            # Create adorner (captures visual BEFORE opacity change)
            $script:dragAdorner = [RdpDragAdorner]::new($window.Content, $SourceElement, $mouseOffsetY)
            $script:dragAdornerLayer.Add($script:dragAdorner)

            # Make source semi-transparent (placeholder effect)
            $SourceElement.Opacity = 0.3
        }

        function Hide-DragAdorner {
            if ($script:dragAdorner -and $script:dragAdornerLayer) {
                $script:dragAdornerLayer.Remove($script:dragAdorner)
                $script:dragAdorner = $null
                $script:dragAdornerLayer = $null
            }
            if ($script:dragSourceElement) {
                $script:dragSourceElement.Opacity = 1.0
                $script:dragSourceElement = $null
            }
        }

        # Helper: find drop index with directional threshold (like react-beautiful-dnd)
        # Dragging DOWN → must pass 65% of target to trigger swap (prevents premature trigger)
        # Dragging UP   → only need to pass 35% of target (feels natural)
        function Get-DropIndex {
            param($Panel, $Position, [int]$CurrentIndex = -1)
            $y = $Position.Y
            $index = 0
            foreach ($child in $Panel.Children) {
                $childPos = $child.TranslatePoint([System.Windows.Point]::new(0, 0), $Panel)
                if ($CurrentIndex -ge 0) {
                    # Directional bias: items below current need higher threshold
                    $ratio = if ($index -ge $CurrentIndex) { 0.65 } else { 0.35 }
                } else {
                    $ratio = 0.5
                }
                $threshold = $childPos.Y + ($child.ActualHeight * $ratio)
                if ($y -gt $threshold) { $index++ } else { break }
            }
            return $index
        }

        # Helper: move child in StackPanel with FLIP animation (First-Last-Invert-Play)
        # Same technique as React dnd-kit / react-beautiful-dnd for smooth reorder
        $script:lastMoveTime = [DateTime]::MinValue

        function Move-PanelChild {
            param($Panel, [int]$FromIndex, [int]$ToIndex)
            if ($FromIndex -eq $ToIndex) { return }

            # Throttle: skip if last move was < 100ms ago (prevents jitter from rapid DragOver)
            $now = [DateTime]::Now
            if (($now - $script:lastMoveTime).TotalMilliseconds -lt 100) { return }
            $script:lastMoveTime = $now

            # FLIP Step 1 (First): record Y positions of ALL children before move
            $oldPositions = @{}
            foreach ($item in $Panel.Children) {
                $pos = $item.TranslatePoint([System.Windows.Point]::new(0, 0), $Panel)
                $oldPositions[$item.GetHashCode()] = $pos.Y
            }

            # FLIP Step 2 (Last): do the actual DOM move
            $child = $Panel.Children[$FromIndex]
            $Panel.Children.RemoveAt($FromIndex)
            if ($ToIndex -gt $Panel.Children.Count) { $ToIndex = $Panel.Children.Count }
            $Panel.Children.Insert($ToIndex, $child)

            # Force layout so new positions are calculated
            $Panel.UpdateLayout()

            # FLIP Step 3+4 (Invert+Play): animate each moved sibling from old→new position
            foreach ($item in $Panel.Children) {
                if ($item -eq $child) { continue }  # Skip dragged item itself
                $hashCode = $item.GetHashCode()
                if (-not $oldPositions.ContainsKey($hashCode)) { continue }

                $newPos = $item.TranslatePoint([System.Windows.Point]::new(0, 0), $Panel)
                $deltaY = $oldPositions[$hashCode] - $newPos.Y

                # Only animate if actually moved (> 1px)
                if ([Math]::Abs($deltaY) -gt 1) {
                    $tt = New-Object System.Windows.Media.TranslateTransform
                    $tt.Y = $deltaY  # Start at OLD position (inverted)
                    $item.RenderTransform = $tt

                    # Animate to 0 (new/final position)
                    $anim = New-Object System.Windows.Media.Animation.DoubleAnimation
                    $anim.From = $deltaY
                    $anim.To = 0
                    $anim.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds(200))
                    $ease = New-Object System.Windows.Media.Animation.CubicEase
                    $ease.EasingMode = [System.Windows.Media.Animation.EasingMode]::EaseOut
                    $anim.EasingFunction = $ease
                    $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $anim)
                }
            }
        }

        # --- Build host list UI ---
        function Update-HostList {
            param([string]$Filter = '')
            $panelCategories.Children.Clear()

            foreach ($cat in $script:rdpData.categories) {
                # Filter hosts
                $filteredHosts = @($cat.hosts | Where-Object {
                    if (-not $Filter) { return $true }
                    $_.name -like "*$Filter*" -or $_.ip -like "*$Filter*"
                })

                if ($Filter -and $filteredHosts.Count -eq 0) { continue }

                # Category container (custom collapsible panel — arrow on the right)
                $catContainer = New-Object System.Windows.Controls.StackPanel
                $catContainer.Margin = [System.Windows.Thickness]::new(0, 4, 0, 0)

                # Header bar
                $headerBorder = New-Object System.Windows.Controls.Border
                $headerBorder.Padding = [System.Windows.Thickness]::new(4, 6, 8, 6)
                $headerBorder.Cursor = [System.Windows.Input.Cursors]::Hand
                $headerBorder.Background = [System.Windows.Media.Brushes]::Transparent

                $headerGrid = New-Object System.Windows.Controls.Grid
                $hcol0 = New-Object System.Windows.Controls.ColumnDefinition; $hcol0.Width = [System.Windows.GridLength]::Auto
                $hcol1 = New-Object System.Windows.Controls.ColumnDefinition; $hcol1.Width = [System.Windows.GridLength]::Auto
                $hcol2 = New-Object System.Windows.Controls.ColumnDefinition; $hcol2.Width = [System.Windows.GridLength]::Auto
                $hcol3 = New-Object System.Windows.Controls.ColumnDefinition; $hcol3.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star)
                $hcol4 = New-Object System.Windows.Controls.ColumnDefinition; $hcol4.Width = [System.Windows.GridLength]::Auto
                $headerGrid.ColumnDefinitions.Add($hcol0)
                $headerGrid.ColumnDefinitions.Add($hcol1)
                $headerGrid.ColumnDefinitions.Add($hcol2)
                $headerGrid.ColumnDefinitions.Add($hcol3)
                $headerGrid.ColumnDefinitions.Add($hcol4)

                # Drag handle
                $dragHandle = New-Object System.Windows.Controls.TextBlock
                $dragHandle.Text = [char]0x2630
                $dragHandle.FontSize = 14
                $dragHandle.Foreground = [System.Windows.Media.Brushes]::Gray
                $dragHandle.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
                $dragHandle.VerticalAlignment = 'Center'
                $dragHandle.Cursor = [System.Windows.Input.Cursors]::SizeAll
                $dragHandle.Background = [System.Windows.Media.Brushes]::Transparent
                [System.Windows.Controls.Grid]::SetColumn($dragHandle, 0)
                $headerGrid.Children.Add($dragHandle) | Out-Null

                # Category drag events
                $catIndex = [Array]::IndexOf($script:rdpData.categories, $cat)
                $dragHandle.Tag = @{ CatIndex = $catIndex; Container = $catContainer }
                $dragHandle.Add_PreviewMouseLeftButtonDown({
                    $script:dragState.StartPos = [System.Windows.Input.Mouse]::GetPosition($window)
                    $script:dragState.Source = $this.Tag.Container
                    $script:dragState.Type = 'category'
                    $script:dragState.CatIndex = $this.Tag.CatIndex
                    $script:dragState.CurrentIndex = $this.Tag.CatIndex
                })
                $dragHandle.Add_PreviewMouseMove({
                    if ($script:dragState.Source -and $script:dragState.Type -eq 'category' -and $_.LeftButton -eq 'Pressed') {
                        $pos = [System.Windows.Input.Mouse]::GetPosition($window)
                        $diff = $pos - $script:dragState.StartPos
                        if ([Math]::Abs($diff.Y) -gt 5) {
                            $script:dragState.Active = $true
                            Show-DragAdorner -SourceElement $this.Tag.Container
                            $data = New-Object System.Windows.DataObject
                            $data.SetData('CategoryDrag', $true)
                            [System.Windows.DragDrop]::DoDragDrop($this.Tag.Container, $data, 'Move') | Out-Null
                            Hide-DragAdorner
                            $script:dragState.Active = $false
                            $script:dragState.Source = $null
                        }
                    }
                })

                # Category name
                $headerText = New-Object System.Windows.Controls.TextBlock
                $headerText.Text = $cat.name
                $headerText.FontSize = 14
                $headerText.FontWeight = [System.Windows.FontWeights]::SemiBold
                $headerText.VerticalAlignment = 'Center'
                [System.Windows.Controls.Grid]::SetColumn($headerText, 1)
                $headerGrid.Children.Add($headerText) | Out-Null

                # Host count
                $hostCount = New-Object System.Windows.Controls.TextBlock
                $hostCount.Text = "  ($($cat.hosts.Count))"
                $hostCount.FontSize = 12
                $hostCount.Foreground = [System.Windows.Media.Brushes]::Gray
                $hostCount.VerticalAlignment = 'Center'
                [System.Windows.Controls.Grid]::SetColumn($hostCount, 2)
                $headerGrid.Children.Add($hostCount) | Out-Null

                # Collapse/expand arrow (right-aligned)
                $arrow = New-Object System.Windows.Controls.TextBlock
                $arrow.FontSize = 12
                $arrow.Foreground = [System.Windows.Media.Brushes]::Gray
                $arrow.VerticalAlignment = 'Center'
                $arrow.Margin = [System.Windows.Thickness]::new(8, 0, 0, 0)
                [System.Windows.Controls.Grid]::SetColumn($arrow, 4)
                $headerGrid.Children.Add($arrow) | Out-Null

                $headerBorder.Child = $headerGrid

                # Restore expand state
                $catState = $script:rdpSettings.categoryState
                $isExpanded = $true
                if ($catState.PSObject.Properties.Name -contains $cat.name) {
                    $isExpanded = [bool]$catState.($cat.name)
                }
                $arrow.Text = if ($isExpanded) { [char]0x25BC } else { [char]0x25B6 }

                # Store state in container tag
                $catContainer.Tag = @{ CatName = $cat.name; IsExpanded = $isExpanded; HostPanel = $null; Arrow = $arrow }

                # Click header to toggle expand/collapse
                $headerBorder.Tag = $catContainer.Tag
                $headerBorder.Add_MouseLeftButtonUp({
                    $tag = $this.Tag
                    if ($tag.IsExpanded) {
                        $tag.HostPanel.Visibility = 'Collapsed'
                        $tag.Arrow.Text = [char]0x25B6
                        $tag.IsExpanded = $false
                    } else {
                        $tag.HostPanel.Visibility = 'Visible'
                        $tag.Arrow.Text = [char]0x25BC
                        $tag.IsExpanded = $true
                    }
                })

                $catContainer.Children.Add($headerBorder) | Out-Null

                # Host list panel
                $hostPanel = New-Object System.Windows.Controls.StackPanel
                $hostPanel.Margin = [System.Windows.Thickness]::new(4, 2, 0, 4)
                $hostPanel.AllowDrop = $true
                $hostPanel.Tag = $cat.name
                if (-not $isExpanded) { $hostPanel.Visibility = 'Collapsed' }
                $catContainer.Tag.HostPanel = $hostPanel

                # Host drop target: DragOver does live reorder (like dnd-kit)
                $hostPanel.Add_DragOver({
                    if ($_.Data.GetDataPresent('HostDrag')) {
                        $sourceCat = $_.Data.GetData('HostDrag')
                        if ($sourceCat -ne $this.Tag) {
                            $_.Effects = 'None'
                            return
                        }
                        $_.Effects = 'Move'
                        $pos = $_.GetPosition($this)
                        $currentIdx = $script:dragState.CurrentIndex
                        $targetIdx = Get-DropIndex -Panel $this -Position $pos -CurrentIndex $currentIdx

                        if ($targetIdx -ne $currentIdx -and $currentIdx -ge 0) {
                            # Move UI element with animation
                            Move-PanelChild -Panel $this -FromIndex $currentIdx -ToIndex $targetIdx

                            # Move data in array
                            $catData = $script:rdpData.categories | Where-Object { $_.name -eq $sourceCat }
                            if ($catData) {
                                $hosts = [System.Collections.ArrayList]@($catData.hosts)
                                $item = $hosts[$currentIdx]
                                $hosts.RemoveAt($currentIdx)
                                if ($targetIdx -gt $hosts.Count) { $targetIdx = $hosts.Count }
                                $hosts.Insert($targetIdx, $item)
                                $catData.hosts = @($hosts)
                                $script:dragState.CurrentIndex = $targetIdx
                            }
                        }
                    }
                    $_.Handled = $true
                })

                # Host drop target: Drop saves final order
                $hostPanel.Add_Drop({
                    if ($_.Data.GetDataPresent('HostDrag')) {
                        Save-RdpData -Data $script:rdpData -Path $script:dataPath
                    }
                    $_.Handled = $true
                })

                foreach ($h in $filteredHosts) {
                    $row = New-Object System.Windows.Controls.Border
                    $row.Background = [System.Windows.Media.Brushes]::White
                    $row.Margin = [System.Windows.Thickness]::new(0, 1, 0, 1)
                    $row.Padding = [System.Windows.Thickness]::new(8, 6, 8, 6)
                    $row.CornerRadius = [System.Windows.CornerRadius]::new(3)

                    # Mouse hover effect
                    $row.Add_MouseEnter({ $this.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#F0F7FF') })
                    $row.Add_MouseLeave({ $this.Background = [System.Windows.Media.Brushes]::White })

                    $grid = New-Object System.Windows.Controls.Grid

                    # Columns: drag(24) | name(2*) | ip(2*) | account(1.5*) | button(auto)
                    $col0 = New-Object System.Windows.Controls.ColumnDefinition; $col0.Width = [System.Windows.GridLength]::new(24)
                    $col1 = New-Object System.Windows.Controls.ColumnDefinition; $col1.Width = [System.Windows.GridLength]::new(2, [System.Windows.GridUnitType]::Star)
                    $col2 = New-Object System.Windows.Controls.ColumnDefinition; $col2.Width = [System.Windows.GridLength]::new(2, [System.Windows.GridUnitType]::Star)
                    $col3 = New-Object System.Windows.Controls.ColumnDefinition; $col3.Width = [System.Windows.GridLength]::new(1.5, [System.Windows.GridUnitType]::Star)
                    $col4 = New-Object System.Windows.Controls.ColumnDefinition; $col4.Width = [System.Windows.GridLength]::Auto
                    $grid.ColumnDefinitions.Add($col0)
                    $grid.ColumnDefinitions.Add($col1)
                    $grid.ColumnDefinitions.Add($col2)
                    $grid.ColumnDefinitions.Add($col3)
                    $grid.ColumnDefinitions.Add($col4)

                    # Drag handle
                    $grip = New-Object System.Windows.Controls.TextBlock
                    $grip.Text = [char]0x2801
                    $grip.FontSize = 14
                    $grip.Foreground = [System.Windows.Media.Brushes]::LightGray
                    $grip.VerticalAlignment = 'Center'
                    $grip.Cursor = [System.Windows.Input.Cursors]::SizeNS
                    $grip.Background = [System.Windows.Media.Brushes]::Transparent
                    [System.Windows.Controls.Grid]::SetColumn($grip, 0)
                    $grid.Children.Add($grip) | Out-Null

                    # Host drag-drop
                    $hostIndex = [Array]::IndexOf($cat.hosts, $h)
                    $grip.Tag = @{ CatName = $cat.name; HostIndex = $hostIndex; Row = $row }
                    $grip.Add_PreviewMouseLeftButtonDown({
                        $script:dragState.StartPos = [System.Windows.Input.Mouse]::GetPosition($window)
                        $script:dragState.Source = $this.Tag.Row
                        $script:dragState.Type = 'host'
                        $script:dragState.CatName = $this.Tag.CatName
                        $script:dragState.HostIndex = $this.Tag.HostIndex
                        $script:dragState.CurrentIndex = $this.Tag.HostIndex
                    })
                    $grip.Add_PreviewMouseMove({
                        if ($script:dragState.Source -and $script:dragState.Type -eq 'host' -and $_.LeftButton -eq 'Pressed') {
                            $pos = [System.Windows.Input.Mouse]::GetPosition($window)
                            $diff = $pos - $script:dragState.StartPos
                            if ([Math]::Abs($diff.Y) -gt 5) {
                                $script:dragState.Active = $true
                                Show-DragAdorner -SourceElement $this.Tag.Row
                                $data = New-Object System.Windows.DataObject
                                $data.SetData('HostDrag', $script:dragState.CatName)
                                [System.Windows.DragDrop]::DoDragDrop($this.Tag.Row, $data, 'Move') | Out-Null
                                Hide-DragAdorner
                                $script:dragState.Active = $false
                                $script:dragState.Source = $null
                            }
                        }
                    })

                    # Host name
                    $nameBlock = New-Object System.Windows.Controls.TextBlock
                    $nameBlock.Text = $h.name
                    $nameBlock.FontSize = 13
                    $nameBlock.VerticalAlignment = 'Center'
                    $nameBlock.TextTrimming = 'CharacterEllipsis'
                    [System.Windows.Controls.Grid]::SetColumn($nameBlock, 1)
                    $grid.Children.Add($nameBlock) | Out-Null

                    # IP
                    $ipBlock = New-Object System.Windows.Controls.TextBlock
                    $ipBlock.Text = $h.ip
                    $ipBlock.FontSize = 13
                    $ipBlock.Foreground = [System.Windows.Media.Brushes]::Gray
                    $ipBlock.VerticalAlignment = 'Center'
                    $ipBlock.TextTrimming = 'CharacterEllipsis'
                    [System.Windows.Controls.Grid]::SetColumn($ipBlock, 2)
                    $grid.Children.Add($ipBlock) | Out-Null

                    # Account ComboBox
                    $combo = New-Object System.Windows.Controls.ComboBox
                    $combo.Margin = [System.Windows.Thickness]::new(4, 0, 4, 0)
                    $combo.VerticalAlignment = 'Center'
                    $combo.MinWidth = 80
                    foreach ($acc in $h.accounts) {
                        $combo.Items.Add($acc.label) | Out-Null
                    }
                    $defaultIdx = if ($null -ne $h.defaultAccount -and $h.defaultAccount -lt $h.accounts.Count) { $h.defaultAccount } else { 0 }
                    $combo.SelectedIndex = $defaultIdx
                    [System.Windows.Controls.Grid]::SetColumn($combo, 3)
                    $grid.Children.Add($combo) | Out-Null

                    # Connect button
                    $btn = New-Object System.Windows.Controls.Button
                    $btn.Content = 'Connect'
                    $btn.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#0078D4')
                    $btn.Foreground = [System.Windows.Media.Brushes]::White
                    $btn.Padding = [System.Windows.Thickness]::new(12, 4, 12, 4)
                    $btn.Margin = [System.Windows.Thickness]::new(4, 0, 0, 0)
                    $btn.BorderThickness = [System.Windows.Thickness]::new(0)
                    $btn.Cursor = [System.Windows.Input.Cursors]::Hand
                    $btn.Tag = @{ Host = $h; ComboBox = $combo }
                    [System.Windows.Controls.Grid]::SetColumn($btn, 4)
                    $grid.Children.Add($btn) | Out-Null

                    # Connect click handler
                    $btn.Add_Click({
                        $info = $this.Tag
                        $hostData = $info.Host
                        $accountIdx = $info.ComboBox.SelectedIndex
                        if ($accountIdx -lt 0) { $accountIdx = 0 }
                        $account = $hostData.accounts[$accountIdx]

                        $params = @{ IP = $hostData.ip }
                        if ($account.username) { $params['Username'] = $account.username }
                        if ($account.password) { $params['CopyPassWD'] = $account.password }

                        if ($rbFullScreen.IsChecked) {
                            $params['FullScreen'] = $true
                        }
                        else {
                            $params['Ratio'] = $script:rdpSettings.ratio
                        }

                        Connect-RdpSession @params
                    })

                    # Double-click row to connect
                    $row.Tag = $btn
                    $row.Add_MouseLeftButtonDown({
                        if ($_.ClickCount -eq 2) {
                            $this.Tag.RaiseEvent(
                                [System.Windows.RoutedEventArgs]::new([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)
                            )
                        }
                    })

                    $row.Child = $grid
                    $hostPanel.Children.Add($row) | Out-Null
                }

                $catContainer.Children.Add($hostPanel) | Out-Null
                $panelCategories.Children.Add($catContainer) | Out-Null
            }
        }

        # --- Category drag-drop on main panel ---
        $panelCategories.AllowDrop = $true
        # Category DragOver: live reorder (like dnd-kit)
        $panelCategories.Add_DragOver({
            if ($_.Data.GetDataPresent('CategoryDrag')) {
                $_.Effects = 'Move'
                $pos = $_.GetPosition($this)
                $currentIdx = $script:dragState.CurrentIndex
                $targetIdx = Get-DropIndex -Panel $this -Position $pos -CurrentIndex $currentIdx

                if ($targetIdx -ne $currentIdx -and $currentIdx -ge 0) {
                    # Move UI element with animation
                    Move-PanelChild -Panel $this -FromIndex $currentIdx -ToIndex $targetIdx

                    # Move data in array
                    $cats = [System.Collections.ArrayList]@($script:rdpData.categories)
                    $item = $cats[$currentIdx]
                    $cats.RemoveAt($currentIdx)
                    if ($targetIdx -gt $cats.Count) { $targetIdx = $cats.Count }
                    $cats.Insert($targetIdx, $item)
                    $script:rdpData.categories = @($cats)
                    $script:dragState.CurrentIndex = $targetIdx
                }
            }
            $_.Handled = $true
        })

        # Category Drop: save final order
        $panelCategories.Add_Drop({
            if ($_.Data.GetDataPresent('CategoryDrag')) {
                Save-RdpData -Data $script:rdpData -Path $script:dataPath
            }
            $_.Handled = $true
        })

        # --- Drag ghost follows cursor (via PreviewGiveFeedback + Win32 GetCursorPos) ---
        $window.Add_PreviewGiveFeedback({
            if ($script:dragAdorner) {
                $script:dragAdorner.UpdatePosition()
            }
        })

        # --- Search with debounce ---
        $script:searchTimer = New-Object System.Windows.Threading.DispatcherTimer
        $script:searchTimer.Interval = [TimeSpan]::FromMilliseconds(300)
        $script:searchTimer.Add_Tick({
            $script:searchTimer.Stop()
            Update-HostList -Filter $txtSearch.Text
        })

        $txtSearch.Add_TextChanged({
            $script:searchTimer.Stop()
            $script:searchTimer.Start()
            $txtSearchPlaceholder.Visibility = if ($txtSearch.Text) { 'Collapsed' } else { 'Visible' }
        })

        # --- Button handlers ---
        $btnEditJson.Add_Click({
            Save-CurrentState
            Start-Process notepad.exe $script:dataPath
        })

        $btnAddHost.Add_Click({
            Show-AddHostDialog -Window $window
        })

        $btnCategoryMgr.Add_Click({
            Show-CategoryDialog -Window $window
        })

        # --- Save state helper ---
        function Save-CurrentState {
            $stateObj = [PSCustomObject]@{}
            foreach ($child in $panelCategories.Children) {
                if ($child.Tag -and $child.Tag.CatName) {
                    $stateObj | Add-Member -NotePropertyName $child.Tag.CatName -NotePropertyValue $child.Tag.IsExpanded -Force
                }
            }
            $script:rdpSettings.categoryState = $stateObj
            $script:rdpSettings.connectionMode = if ($rbFullScreen.IsChecked) { 'fullscreen' } else { 'windowed' }
            $script:rdpSettings.window = [PSCustomObject]@{
                width  = [int]$window.ActualWidth
                height = [int]$window.ActualHeight
                left   = [int]$window.Left
                top    = [int]$window.Top
            }
            Save-RdpSettings -Settings $script:rdpSettings -Path $script:settingsPath
        }

        # --- Window closing ---
        $window.Add_Closing({
            Save-CurrentState
        })

        # --- F5 = reload XAML + data ---
        $window.Add_KeyDown({
            if ($_.Key -eq 'F5') {
                $script:reloadRequested = $true
                Save-CurrentState
                $window.Close()
            }
        })

        # --- Add Host Dialog ---
        function Show-AddHostDialog {
            param($Window)

            $dlg = Import-Xaml (Join-Path $xamlDir 'AddHostDialog.xaml')
            $dlg.Owner = $Window

            $dlgCategory = $dlg.FindName('DlgCategory')
            $dlgName = $dlg.FindName('DlgName')
            $dlgIp = $dlg.FindName('DlgIp')
            $dlgLabel = $dlg.FindName('DlgLabel')
            $dlgUsername = $dlg.FindName('DlgUsername')
            $dlgPassword = $dlg.FindName('DlgPassword')
            $dlgOk = $dlg.FindName('DlgOk')
            $dlgCancel = $dlg.FindName('DlgCancel')

            foreach ($cat in $script:rdpData.categories) {
                $dlgCategory.Items.Add($cat.name) | Out-Null
            }
            if ($dlgCategory.Items.Count -gt 0) { $dlgCategory.SelectedIndex = 0 }

            $dlgOk.Add_Click({
                if (-not $dlgName.Text -or -not $dlgIp.Text) {
                    [System.Windows.MessageBox]::Show('Name and IP are required.', 'Validation', 'OK', 'Warning')
                    return
                }
                $catName = $dlgCategory.SelectedItem
                $targetCat = $script:rdpData.categories | Where-Object { $_.name -eq $catName }

                $newHost = [PSCustomObject]@{
                    name           = $dlgName.Text
                    ip             = $dlgIp.Text
                    order          = $targetCat.hosts.Count
                    accounts       = @(
                        [PSCustomObject]@{
                            label    = if ($dlgLabel.Text) { $dlgLabel.Text } else { $dlgUsername.Text }
                            username = $dlgUsername.Text
                            password = $dlgPassword.Password
                        }
                    )
                    defaultAccount = 0
                }

                $targetCat.hosts = @($targetCat.hosts) + @($newHost)
                Save-RdpData -Data $script:rdpData -Path $script:dataPath
                Update-HostList -Filter $txtSearch.Text
                $dlg.Close()
            })

            $dlgCancel.Add_Click({ $dlg.Close() })
            $dlg.ShowDialog() | Out-Null
        }

        # --- Category Management Dialog ---
        function Show-CategoryDialog {
            param($Window)

            $catDlg = Import-Xaml (Join-Path $xamlDir 'CategoryDialog.xaml')
            $catDlg.Owner = $Window

            $catList = $catDlg.FindName('CatList')
            $catNewName = $catDlg.FindName('CatNewName')
            $catAdd = $catDlg.FindName('CatAdd')
            $catUp = $catDlg.FindName('CatUp')
            $catDown = $catDlg.FindName('CatDown')
            $catRename = $catDlg.FindName('CatRename')
            $catDelete = $catDlg.FindName('CatDelete')

            function Refresh-CatList {
                $sel = $catList.SelectedIndex
                $catList.Items.Clear()
                foreach ($c in $script:rdpData.categories) {
                    $catList.Items.Add($c.name) | Out-Null
                }
                if ($sel -ge 0 -and $sel -lt $catList.Items.Count) { $catList.SelectedIndex = $sel }
            }
            Refresh-CatList

            $catAdd.Add_Click({
                $name = $catNewName.Text.Trim()
                if (-not $name) { return }
                if ($script:rdpData.categories | Where-Object { $_.name -eq $name }) {
                    [System.Windows.MessageBox]::Show("Category '$name' already exists.", 'Error', 'OK', 'Warning')
                    return
                }
                $newCat = [PSCustomObject]@{ name = $name; order = $script:rdpData.categories.Count; hosts = @() }
                $script:rdpData.categories = @($script:rdpData.categories) + @($newCat)
                $catNewName.Text = ''
                Refresh-CatList
            })

            $catUp.Add_Click({
                $idx = $catList.SelectedIndex
                if ($idx -le 0) { return }
                $cats = @($script:rdpData.categories)
                $cats[$idx], $cats[$idx - 1] = $cats[$idx - 1], $cats[$idx]
                $script:rdpData.categories = $cats
                Refresh-CatList
                $catList.SelectedIndex = $idx - 1
            })

            $catDown.Add_Click({
                $idx = $catList.SelectedIndex
                if ($idx -lt 0 -or $idx -ge $catList.Items.Count - 1) { return }
                $cats = @($script:rdpData.categories)
                $cats[$idx], $cats[$idx + 1] = $cats[$idx + 1], $cats[$idx]
                $script:rdpData.categories = $cats
                Refresh-CatList
                $catList.SelectedIndex = $idx + 1
            })

            $catRename.Add_Click({
                $idx = $catList.SelectedIndex
                if ($idx -lt 0) { return }
                $oldName = $script:rdpData.categories[$idx].name
                $newName = $catNewName.Text.Trim()
                if (-not $newName) {
                    [System.Windows.MessageBox]::Show('Enter new name in the text box.', 'Rename', 'OK', 'Information')
                    return
                }
                if ($script:rdpSettings.categoryState.PSObject.Properties.Name -contains $oldName) {
                    $val = $script:rdpSettings.categoryState.$oldName
                    $script:rdpSettings.categoryState.PSObject.Properties.Remove($oldName)
                    $script:rdpSettings.categoryState | Add-Member -NotePropertyName $newName -NotePropertyValue $val -Force
                }
                $script:rdpData.categories[$idx].name = $newName
                $catNewName.Text = ''
                Refresh-CatList
            })

            $catDelete.Add_Click({
                $idx = $catList.SelectedIndex
                if ($idx -lt 0) { return }
                $cat = $script:rdpData.categories[$idx]
                if ($cat.hosts.Count -gt 0) {
                    $result = [System.Windows.MessageBox]::Show(
                        "Category '$($cat.name)' has $($cat.hosts.Count) host(s). Delete anyway?",
                        'Confirm Delete', 'YesNo', 'Warning')
                    if ($result -ne 'Yes') { return }
                }
                $script:rdpData.categories = @($script:rdpData.categories | Where-Object { $_.name -ne $cat.name })
                Refresh-CatList
            })

            $catDlg.Add_Closing({
                Save-RdpData -Data $script:rdpData -Path $script:dataPath
                Update-HostList -Filter $txtSearch.Text
            })

            $catDlg.ShowDialog() | Out-Null
        }

        # --- Initial render ---
        Update-HostList

        # --- Show window (blocks until closed) ---
        $window.ShowDialog() | Out-Null

    } # end while reload loop
}
