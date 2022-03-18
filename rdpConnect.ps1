function rdpConnect {
    [CmdletBinding(DefaultParameterSetName = "A")]
    param (
        [Parameter(Mandatory, Position = 0, ParameterSetName = "")]
        [string] $IP,
        [Parameter(Position = 1, ParameterSetName = "")]
        [String] $Password,
        # 傻瓜包
        [Parameter(ParameterSetName = "A")]
        [switch] $Nomal,
        
        [Parameter(ParameterSetName = "B")]
        [switch] $MaxWindows,
        [Parameter(ParameterSetName = "C")]
        [switch] $FullScreen,
        # 自訂模式
        [Parameter(ParameterSetName = "D")]
        [uint64] $device_w,
        [Parameter(ParameterSetName = "D")]
        [uint64] $device_h,
        [Parameter(ParameterSetName = "D")]
        [uint64] $x1,
        [Parameter(ParameterSetName = "D")]
        [uint64] $y1
    )
    # 獲取螢幕解析度
    Add-Type -AssemblyName System.Windows.Forms
    # 設置參數
    $IP      = $IP
    $width   = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.width
    $height  = [System.Windows.Forms.SystemInformation]::PrimaryMonitorSize.height
    $x1      = 0
    $y1      = 0
    $title_h = 30
    $star_h  = 40
    
    # 遠端裝置解析度
    $device_w = $width - 16
    $device_h = $height - ($title_h+$star_h+16)
    $x2 = $x1+$device_w +16
    $y2 = $y1+$device_h +16 + $title_h
    # 設定模式
    $Nomal = $true
    if ($MaxWindows) {$Nomal = $false}
    if ($Nomal) {
        $new_w = $device_h/3*4
        $x1 = $device_w - $new_w
        $device_w = $new_w
    }
    # 檢查是否超過螢幕
    $device_x_max = $width
    $device_y_max = $height-$star_h
    if ($x2 -gt $device_x_max) { $x2 = $device_x_max }
    if ($y2 -gt $device_y_max) { $y2 = $device_y_max }
    
    #  設置參數
    # $rdp = Get-Content 'Template.rdp'
    $rdp = Invoke-RestMethod 'raw.githubusercontent.com/hunandy14/rdpConnect/master/Template.rdp'
    $rdp = $rdp.Replace('${ip}'     ,$ip)
    $rdp = $rdp.Replace('${width}'  ,$device_w)
    $rdp = $rdp.Replace('${height}' ,$device_h)
    $rdp = $rdp.Replace('${x1}'     ,$x1)
    $rdp = $rdp.Replace('${y1}'     ,$y1+7)
    $rdp = $rdp.Replace('${x2}'     ,$x2)
    $rdp = $rdp.Replace('${y2}'     ,$y2)

    $rdp_path = "$env:TEMP\Default.rdp"
    Set-Content $rdp_path $rdp
    Set-Clipboard $Password
    Start-Process $rdp_path
}

function __rdpConnect_Tester__ {
    # rdpConnect 10.216.242.174
    rdpConnect 192.168.3.12 'P@ssw0rd3'
} __rdpConnect_Tester__
