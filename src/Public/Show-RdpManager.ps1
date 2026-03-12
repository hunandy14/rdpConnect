#Requires -Version 5.1

<#
.SYNOPSIS
    WPF GUI for managing RDP connections.

.DESCRIPTION
    Displays a modern WPF window with categorized server list,
    multiple accounts per host, search filtering, and drag-drop reordering.

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

    # --- Resolve paths ---
    $paths = Get-RdpDataPath -BasePath $(if ($Path) { Split-Path $Path -Parent } else { $null })
    if ($Path) { $paths.DataPath = $Path }

    if (-not (Test-Path $paths.DataPath)) {
        # Create from example if available
        $examplePath = Join-Path $paths.BasePath 'rdpList.example.json'
        if (Test-Path $examplePath) {
            Copy-Item $examplePath $paths.DataPath
            Write-Host "Created rdpList.json from example file." -ForegroundColor Cyan
        }
        else {
            throw "RDP data file not found: $($paths.DataPath)`nCreate it or place rdpList.example.json in the same directory."
        }
    }

    # --- Load data ---
    $script:rdpData = Import-RdpData -Path $paths.DataPath
    $script:rdpSettings = Import-RdpSettings -Path $paths.SettingsPath
    $script:dataPath = $paths.DataPath
    $script:settingsPath = $paths.SettingsPath

    # --- XAML ---
    [xml]$xaml = @'
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="RDP Manager" MinWidth="500" MinHeight="350"
    WindowStartupLocation="CenterScreen"
    Background="#F5F5F5">
    <Window.Resources>
        <Style x:Key="ConnectButton" TargetType="Button">
            <Setter Property="Background" Value="#0078D4"/>
            <Setter Property="Foreground" Value="White"/>
            <Setter Property="Padding" Value="12,4"/>
            <Setter Property="Margin" Value="4,0,0,0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#106EBE"/>
                            </Trigger>
                            <Trigger Property="IsPressed" Value="True">
                                <Setter Property="Background" Value="#005A9E"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="ToolBarButton" TargetType="Button">
            <Setter Property="Background" Value="#E0E0E0"/>
            <Setter Property="Padding" Value="10,5"/>
            <Setter Property="Margin" Value="2,0"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border Background="{TemplateBinding Background}"
                                CornerRadius="3" Padding="{TemplateBinding Padding}">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter Property="Background" Value="#D0D0D0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="HostRow" TargetType="Border">
            <Setter Property="Background" Value="White"/>
            <Setter Property="Margin" Value="0,1"/>
            <Setter Property="Padding" Value="8,6"/>
            <Setter Property="CornerRadius" Value="3"/>
            <Style.Triggers>
                <Trigger Property="IsMouseOver" Value="True">
                    <Setter Property="Background" Value="#F0F7FF"/>
                </Trigger>
            </Style.Triggers>
        </Style>
    </Window.Resources>
    <DockPanel>
        <!-- Toolbar -->
        <Border DockPanel.Dock="Top" Background="#FAFAFA" Padding="8,6" BorderBrush="#E0E0E0" BorderThickness="0,0,0,1">
            <DockPanel>
                <StackPanel DockPanel.Dock="Right" Orientation="Horizontal">
                    <Button x:Name="BtnAddHost" Content="&#x2795; New Host" Style="{StaticResource ToolBarButton}"/>
                    <Button x:Name="BtnCategoryMgr" Content="&#x1F4C1; Categories" Style="{StaticResource ToolBarButton}"/>
                    <Button x:Name="BtnEditJson" Content="&#x1F4DD; Edit" Style="{StaticResource ToolBarButton}"/>
                </StackPanel>
                <Grid>
                    <TextBox x:Name="TxtSearch" Padding="6,4" FontSize="13" BorderBrush="#CCC" BorderThickness="1"
                             Background="White" VerticalContentAlignment="Center"/>
                    <TextBlock x:Name="TxtSearchPlaceholder" Text="Search..." IsHitTestVisible="False"
                               Padding="8,5" FontSize="13" Foreground="#AAA"
                               VerticalAlignment="Center"/>
                </Grid>
            </DockPanel>
        </Border>

        <!-- Connection mode bar -->
        <Border DockPanel.Dock="Bottom" Background="#FAFAFA" Padding="8,5" BorderBrush="#E0E0E0" BorderThickness="0,1,0,0">
            <DockPanel>
                <StackPanel Orientation="Horizontal">
                    <TextBlock Text="Mode:" VerticalAlignment="Center" Margin="0,0,6,0" Foreground="#666"/>
                    <RadioButton x:Name="RbWindowed" Content="Windowed" VerticalAlignment="Center" Margin="0,0,12,0" GroupName="ConnMode"/>
                    <RadioButton x:Name="RbFullScreen" Content="FullScreen" VerticalAlignment="Center" GroupName="ConnMode"/>
                </StackPanel>
            </DockPanel>
        </Border>

        <!-- Main content -->
        <ScrollViewer VerticalScrollBarVisibility="Auto" Padding="8,4">
            <StackPanel x:Name="PanelCategories"/>
        </ScrollViewer>
    </DockPanel>
</Window>
'@

    # Remove x:Class if present (not needed for runtime loading)
    $xaml.Window.RemoveAttribute('x:Class') 2>$null

    $reader = [System.Xml.XmlNodeReader]::new($xaml)
    $window = [System.Windows.Markup.XamlReader]::Load($reader)

    # --- Get UI elements ---
    $txtSearch = $window.FindName('TxtSearch')
    $txtSearchPlaceholder = $window.FindName('TxtSearchPlaceholder')
    $panelCategories = $window.FindName('PanelCategories')
    $rbWindowed = $window.FindName('RbWindowed')
    $rbFullScreen = $window.FindName('RbFullScreen')
    $btnAddHost = $window.FindName('BtnAddHost')
    $btnCategoryMgr = $window.FindName('BtnCategoryMgr')
    $btnEditJson = $window.FindName('BtnEditJson')

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
        Active    = $false
        Source    = $null        # the Border/Expander being dragged
        StartPos  = $null
        Type      = $null        # 'host' or 'category'
        CatName   = $null        # source category name (for host drag)
        HostIndex = -1           # source host index
        CatIndex  = -1           # source category index
        Indicator = $null        # visual drop indicator line
    }

    # Create drop indicator (a thin blue line)
    $script:dropIndicator = New-Object System.Windows.Controls.Border
    $script:dropIndicator.Height = 2
    $script:dropIndicator.Background = [System.Windows.Media.BrushConverter]::new().ConvertFrom('#0078D4')
    $script:dropIndicator.Visibility = 'Collapsed'
    $script:dropIndicator.HorizontalAlignment = 'Stretch'
    $script:dropIndicator.Margin = [System.Windows.Thickness]::new(0, -1, 0, -1)
    $script:dropIndicator.IsHitTestVisible = $false

    # Helper: find the index of a child in a StackPanel based on Y position
    function Get-DropIndex {
        param($Panel, $Position)
        $y = $Position.Y
        $index = 0
        foreach ($child in $Panel.Children) {
            if ($child -eq $script:dropIndicator) { continue }
            $childPos = $child.TranslatePoint([System.Windows.Point]::new(0, 0), $Panel)
            $childMid = $childPos.Y + ($child.ActualHeight / 2)
            if ($y -gt $childMid) { $index++ } else { break }
        }
        return $index
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
            $dragHandle.Text = [char]0x2630  # hamburger menu icon
            $dragHandle.FontSize = 14
            $dragHandle.Foreground = [System.Windows.Media.Brushes]::Gray
            $dragHandle.Margin = [System.Windows.Thickness]::new(0, 0, 8, 0)
            $dragHandle.VerticalAlignment = 'Center'
            $dragHandle.Cursor = [System.Windows.Input.Cursors]::SizeAll
            $dragHandle.Background = [System.Windows.Media.Brushes]::Transparent
            [System.Windows.Controls.Grid]::SetColumn($dragHandle, 0)
            $headerGrid.Children.Add($dragHandle) | Out-Null

            # Category drag: start from header handle
            $catIndex = [Array]::IndexOf($script:rdpData.categories, $cat)
            $dragHandle.Tag = @{ CatIndex = $catIndex; Container = $catContainer }
            $dragHandle.Add_PreviewMouseLeftButtonDown({
                $script:dragState.StartPos = [System.Windows.Input.Mouse]::GetPosition($window)
                $script:dragState.Source = $this.Tag.Container
                $script:dragState.Type = 'category'
                $script:dragState.CatIndex = $this.Tag.CatIndex
            })
            $dragHandle.Add_PreviewMouseMove({
                if ($script:dragState.Source -and $script:dragState.Type -eq 'category' -and $_.LeftButton -eq 'Pressed') {
                    $pos = [System.Windows.Input.Mouse]::GetPosition($window)
                    $diff = $pos - $script:dragState.StartPos
                    if ([Math]::Abs($diff.Y) -gt 5) {
                        $script:dragState.Active = $true
                        $data = New-Object System.Windows.DataObject
                        $data.SetData('CategoryDrag', $true)
                        [System.Windows.DragDrop]::DoDragDrop($this.Tag.Container, $data, 'Move') | Out-Null
                        $script:dragState.Active = $false
                        $script:dragState.Source = $null
                        $script:dropIndicator.Visibility = 'Collapsed'
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

            # Host drop target: DragOver shows indicator
            $hostPanel.Add_DragOver({
                if ($_.Data.GetDataPresent('HostDrag')) {
                    $sourceCat = $_.Data.GetData('HostDrag')
                    if ($sourceCat -ne $this.Tag) {
                        $_.Effects = 'None'
                        return
                    }
                    $_.Effects = 'Move'
                    # Show drop indicator
                    $pos = $_.GetPosition($this)
                    $idx = Get-DropIndex -Panel $this -Position $pos
                    # Remove indicator from old position
                    if ($script:dropIndicator.Parent) {
                        $script:dropIndicator.Parent.Children.Remove($script:dropIndicator)
                    }
                    $script:dropIndicator.Visibility = 'Visible'
                    if ($idx -ge $this.Children.Count) {
                        $this.Children.Add($script:dropIndicator) | Out-Null
                    }
                    else {
                        $this.Children.Insert($idx, $script:dropIndicator) | Out-Null
                    }
                }
                $_.Handled = $true
            })

            $hostPanel.Add_DragLeave({
                if ($script:dropIndicator.Parent -eq $this) {
                    $this.Children.Remove($script:dropIndicator)
                    $script:dropIndicator.Visibility = 'Collapsed'
                }
            })

            # Host drop target: Drop reorders
            $hostPanel.Add_Drop({
                if ($_.Data.GetDataPresent('HostDrag')) {
                    $sourceCat = $_.Data.GetData('HostDrag')
                    if ($sourceCat -ne $this.Tag) { return }

                    # Remove indicator
                    if ($script:dropIndicator.Parent) {
                        $script:dropIndicator.Parent.Children.Remove($script:dropIndicator)
                        $script:dropIndicator.Visibility = 'Collapsed'
                    }

                    $pos = $_.GetPosition($this)
                    $targetIdx = Get-DropIndex -Panel $this -Position $pos
                    $sourceIdx = $script:dragState.HostIndex

                    # Find category in data
                    $catData = $script:rdpData.categories | Where-Object { $_.name -eq $sourceCat }
                    if ($catData -and $sourceIdx -ne $targetIdx) {
                        $hosts = [System.Collections.ArrayList]@($catData.hosts)
                        $item = $hosts[$sourceIdx]
                        $hosts.RemoveAt($sourceIdx)
                        if ($targetIdx -gt $sourceIdx) { $targetIdx-- }
                        if ($targetIdx -gt $hosts.Count) { $targetIdx = $hosts.Count }
                        $hosts.Insert($targetIdx, $item)
                        $catData.hosts = @($hosts)
                        Save-RdpData -Data $script:rdpData -Path $script:dataPath
                        Update-HostList -Filter $txtSearch.Text
                    }
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

                # Columns: drag(20) | name(2*) | ip(2*) | account(1.5*) | button(auto)
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
                $grip.Text = [char]0x2801  # braille dot pattern
                $grip.FontSize = 14
                $grip.Foreground = [System.Windows.Media.Brushes]::LightGray
                $grip.VerticalAlignment = 'Center'
                $grip.Cursor = [System.Windows.Input.Cursors]::SizeNS
                $grip.Background = [System.Windows.Media.Brushes]::Transparent  # needed for hit test
                [System.Windows.Controls.Grid]::SetColumn($grip, 0)
                $grid.Children.Add($grip) | Out-Null

                # Host drag-drop: start drag from grip
                $hostIndex = [Array]::IndexOf($cat.hosts, $h)
                $grip.Tag = @{ CatName = $cat.name; HostIndex = $hostIndex; Row = $row }
                $grip.Add_PreviewMouseLeftButtonDown({
                    $script:dragState.StartPos = [System.Windows.Input.Mouse]::GetPosition($window)
                    $script:dragState.Source = $this.Tag.Row
                    $script:dragState.Type = 'host'
                    $script:dragState.CatName = $this.Tag.CatName
                    $script:dragState.HostIndex = $this.Tag.HostIndex
                })
                $grip.Add_PreviewMouseMove({
                    if ($script:dragState.Source -and $script:dragState.Type -eq 'host' -and $_.LeftButton -eq 'Pressed') {
                        $pos = [System.Windows.Input.Mouse]::GetPosition($window)
                        $diff = $pos - $script:dragState.StartPos
                        if ([Math]::Abs($diff.Y) -gt 5) {
                            $script:dragState.Active = $true
                            $data = New-Object System.Windows.DataObject
                            $data.SetData('HostDrag', $script:dragState.CatName)
                            [System.Windows.DragDrop]::DoDragDrop($this.Tag.Row, $data, 'Move') | Out-Null
                            $script:dragState.Active = $false
                            $script:dragState.Source = $null
                            # Remove indicator
                            $script:dropIndicator.Visibility = 'Collapsed'
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
    $panelCategories.Add_DragOver({
        if ($_.Data.GetDataPresent('CategoryDrag')) {
            $_.Effects = 'Move'
            $pos = $_.GetPosition($this)
            $idx = Get-DropIndex -Panel $this -Position $pos
            if ($script:dropIndicator.Parent) {
                $script:dropIndicator.Parent.Children.Remove($script:dropIndicator)
            }
            $script:dropIndicator.Visibility = 'Visible'
            if ($idx -ge $this.Children.Count) {
                $this.Children.Add($script:dropIndicator) | Out-Null
            }
            else {
                $this.Children.Insert($idx, $script:dropIndicator) | Out-Null
            }
        }
        $_.Handled = $true
    })

    $panelCategories.Add_DragLeave({
        if ($script:dropIndicator.Parent -eq $this) {
            $this.Children.Remove($script:dropIndicator)
            $script:dropIndicator.Visibility = 'Collapsed'
        }
    })

    $panelCategories.Add_Drop({
        if ($_.Data.GetDataPresent('CategoryDrag')) {
            if ($script:dropIndicator.Parent) {
                $script:dropIndicator.Parent.Children.Remove($script:dropIndicator)
                $script:dropIndicator.Visibility = 'Collapsed'
            }

            $pos = $_.GetPosition($this)
            $targetIdx = Get-DropIndex -Panel $this -Position $pos
            $sourceIdx = $script:dragState.CatIndex

            if ($sourceIdx -ne $targetIdx) {
                $cats = [System.Collections.ArrayList]@($script:rdpData.categories)
                $item = $cats[$sourceIdx]
                $cats.RemoveAt($sourceIdx)
                if ($targetIdx -gt $sourceIdx) { $targetIdx-- }
                if ($targetIdx -gt $cats.Count) { $targetIdx = $cats.Count }
                $cats.Insert($targetIdx, $item)
                $script:rdpData.categories = @($cats)
                Save-RdpData -Data $script:rdpData -Path $script:dataPath
                Update-HostList -Filter $txtSearch.Text
            }
        }
        $_.Handled = $true
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
        # Update placeholder visibility
        $txtSearchPlaceholder.Visibility = if ($txtSearch.Text) { 'Collapsed' } else { 'Visible' }
    })

    # --- Button handlers ---
    $btnEditJson.Add_Click({
        # Save current state first
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
        # Save category expand states
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

    # --- Add Host Dialog ---
    function Show-AddHostDialog {
        param($Window)

        [xml]$dlgXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Add Host" Width="400" Height="300" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" Background="#F5F5F5">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="80"/>
            <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>

        <TextBlock Grid.Row="0" Text="Category:" VerticalAlignment="Center" Margin="0,0,0,6"/>
        <ComboBox x:Name="DlgCategory" Grid.Row="0" Grid.Column="1" Margin="0,0,0,6"/>

        <TextBlock Grid.Row="1" Text="Name:" VerticalAlignment="Center" Margin="0,0,0,6"/>
        <TextBox x:Name="DlgName" Grid.Row="1" Grid.Column="1" Margin="0,0,0,6" Padding="4,3"/>

        <TextBlock Grid.Row="2" Text="IP:" VerticalAlignment="Center" Margin="0,0,0,6"/>
        <TextBox x:Name="DlgIp" Grid.Row="2" Grid.Column="1" Margin="0,0,0,6" Padding="4,3"/>

        <TextBlock Grid.Row="3" Text="Label:" VerticalAlignment="Center" Margin="0,0,0,6"/>
        <TextBox x:Name="DlgLabel" Grid.Row="3" Grid.Column="1" Margin="0,0,0,6" Padding="4,3"/>

        <TextBlock Grid.Row="4" Text="Username:" VerticalAlignment="Center" Margin="0,0,0,6"/>
        <TextBox x:Name="DlgUsername" Grid.Row="4" Grid.Column="1" Margin="0,0,0,6" Padding="4,3"/>

        <TextBlock Grid.Row="5" Text="Password:" VerticalAlignment="Center" Margin="0,0,0,6"/>
        <PasswordBox x:Name="DlgPassword" Grid.Row="5" Grid.Column="1" Margin="0,0,0,6" Padding="4,3"/>

        <StackPanel Grid.Row="7" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="DlgOk" Content="OK" Width="70" Margin="0,0,8,0" Padding="4,4"
                    Background="#0078D4" Foreground="White" BorderThickness="0"/>
            <Button x:Name="DlgCancel" Content="Cancel" Width="70" Padding="4,4" BorderThickness="0"/>
        </StackPanel>
    </Grid>
</Window>
'@
        $dlgReader = [System.Xml.XmlNodeReader]::new($dlgXaml)
        $dlg = [System.Windows.Markup.XamlReader]::Load($dlgReader)
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

        [xml]$catXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Category Management" Width="350" Height="350" WindowStartupLocation="CenterOwner"
        ResizeMode="NoResize" Background="#F5F5F5">
    <Grid Margin="16">
        <Grid.RowDefinitions>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <ListBox x:Name="CatList" Grid.Row="0" Margin="0,0,0,8"/>

        <DockPanel Grid.Row="1" Margin="0,0,0,8">
            <Button x:Name="CatAdd" DockPanel.Dock="Right" Content="Add" Width="50" Margin="4,0,0,0" Padding="4,3"/>
            <TextBox x:Name="CatNewName" Padding="4,3"/>
        </DockPanel>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="CatUp" Content="Up" Width="50" Margin="0,0,4,0" Padding="4,3"/>
            <Button x:Name="CatDown" Content="Down" Width="50" Margin="0,0,4,0" Padding="4,3"/>
            <Button x:Name="CatRename" Content="Rename" Width="60" Margin="0,0,4,0" Padding="4,3"/>
            <Button x:Name="CatDelete" Content="Delete" Width="60" Padding="4,3" Background="#D32F2F" Foreground="White" BorderThickness="0"/>
        </StackPanel>
    </Grid>
</Window>
'@
        $catReader = [System.Xml.XmlNodeReader]::new($catXaml)
        $catDlg = [System.Windows.Markup.XamlReader]::Load($catReader)
        $catDlg.Owner = $Window

        $catList = $catDlg.FindName('CatList')
        $catNewName = $catDlg.FindName('CatNewName')
        $catAdd = $catDlg.FindName('CatAdd')
        $catUp = $catDlg.FindName('CatUp')
        $catDown = $catDlg.FindName('CatDown')
        $catRename = $catDlg.FindName('CatRename')
        $catDelete = $catDlg.FindName('CatDelete')

        # Populate list
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
            # Update category state key
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

    # --- Show window ---
    $window.ShowDialog() | Out-Null
}
