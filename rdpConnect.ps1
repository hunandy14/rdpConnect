function rdpConnect {
    param (
        [string] $IP,
        [uint64] $width,
        [uint64] $height 
    )
    $set_h  = (40+30+2)

    $IP     = $IP
    $width  = 2560
    # $height = 1440
    $height = 1600
    $x1     = 0
    $y1     = 0
    
    # $rdp = Get-Content 'Template.rdp'
    $rdp = irm 'raw.githubusercontent.com/hunandy14/rdpConnect/master/Template.rdp'
    
    $height = $height - $set_h
    $rdp = $rdp.Replace('${ip}'     ,$ip)
    $rdp = $rdp.Replace('${width}'  ,$width-16)
    $rdp = $rdp.Replace('${height}' ,$height-16)
    $rdp = $rdp.Replace('${x1}'     ,$x1)
    $rdp = $rdp.Replace('${y1}'     ,$y1+8)
    $rdp = $rdp.Replace('${x2}'     ,($x1+$width))
    $rdp = $rdp.Replace('${y2}'     ,($y1+$height)+31)
    
    $rdp > "Default.rdp"
    Set-Clipboard 'P@ssw0rd3'
    Start-Process 'Default.rdp'
} 

function __rdpConnect_Tester__ {
    # rdpConnect 10.216.242.174
    rdpConnect 192.168.3.12
} __rdpConnect_Tester__

function rdpConnectAutoSize {
    param (
        [string] $IP
    )
    $IP     = $IP
    $width  = 1920
    $height = 1080
    $x1     = 0
    $y1     = 0
    $x2     = ($x1+$width )+ 0
    $y2     = ($y1+$height)- 40
    
    $rdp = Get-Content 'Template.rdp'
    $rdp = $rdp.Replace('${ip}'     ,$ip)
    $rdp = $rdp.Replace('${width}'  ,$width)
    $rdp = $rdp.Replace('${height}' ,$height)
    $rdp = $rdp.Replace('${x1}'     ,$x1)
    $rdp = $rdp.Replace('${y1}'     ,$y1+8)
    $rdp = $rdp.Replace('${x2}'     ,$x2)
    $rdp = $rdp.Replace('${y2}'     ,$y2)
    
    $rdp > "Default.rdp"
} 