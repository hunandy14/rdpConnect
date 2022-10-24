演算法紀錄
===

完全靠賽蝦亂條的，紀錄一下版本條壞了好參考

# 2022-10-24
```ps1
# 計算最大化的視窗數值
function rdpMaxSize {
    param (
        [String] $Width,
        [String] $Height,
        [double] $Scaling
    )
    # 初始數據
    $star   = 40
    $title  = (30-2)
    $margin = 7
    # 縮放後取到偶數
    $margin2 = ($Scaling*$margin)
    $title2  = ($Scaling*$title )
    $star2   = ($Scaling*$star  )
    # $margin2 = [Math]::Round(($Scaling*$margin), 0, [MidpointRounding]::ToEven)
    # $title2  = [Math]::Round(($Scaling*$title ), 0, [MidpointRounding]::ToEven)
    # $star2   = [Math]::Round(($Scaling*$star  ), 0, [MidpointRounding]::ToEven)
    # Write-Host $margin2
    # 計算實際邊緣寬度
    $mgW = ($margin2+$margin2)+0.5
    $mgH = ($title2+2+$margin2+2)-($Scaling*$Scaling*1.75-2)
    # $mgW = ($mgW)
    # $mgH = ($mgH)
    # $mgW = RoundToEven($mgW+0.5)
    # $mgH = RoundToEven($mgH+0.5)
    # $mgW = [Math]::Round(($mgW+0.5), 0, [MidpointRounding]::ToEven)
    # $mgH = [Math]::Round(($mgH+0.5), 0, [MidpointRounding]::ToEven)
    # 輸出視窗範圍
    $x2 = $Width
    $y2 = ($Height - $star2)
    $x1 = 0
    # $y1 = ($margin2)
    # $y1 = RoundToEven($margin2+0.5)
    # $y1 = RoundToEven($margin2+0.5)
    $y1 = [Math]::Round(($margin2+0.5), 0, [MidpointRounding]::ToEven)
    
    # 計算解度
    $w = ($x2-$x1-$mgW)
    $h = ($y2-$y1-$mgH)
    $w = FloorToEven($w-0)
    $h = FloorToEven($h-0)
    # $w = [Math]::Round(($w-0.5), 0, [MidpointRounding]::ToEven)
    # $h = [Math]::Round(($h-0.5), 0, [MidpointRounding]::ToEven)
    # 輸出rdpInfo
    $rdp = [PSCustomObject]@{
        Ip         = $ip
        Resolution = @($w,$h)
        Winposstr  = @($x1, $y1, $x2, $y2)
        Margin     = @($mgW, $mgH)
        Scaling    = $Scaling
        Path       = '.\Default.rdp'
    }
    return $rdp
} 
```



# 2022-10-8
```ps1
# 計算最大化的視窗數值
function rdpMaxSize {
    param (
        [String] $Width,
        [String] $Height,
        [double] $Scaling=1.0
    )
    # 初始數據
    $star   = 40
    $title  = (30-2)
    $margin = 7
    # 縮放後取到偶數
    $margin2 = [Math]::Round(($Scaling*$margin), 0, [MidpointRounding]::ToEven)
    $title2  = [Math]::Round(($Scaling*$title ), 0, [MidpointRounding]::ToEven)
    $star2   = [Math]::Round(($Scaling*$star  ), 0, [MidpointRounding]::ToEven)
    # 計算實際邊緣寬度
    $mgW = $margin2+$margin2+1
    $mgH = $title2+2+$margin2+2
    $mgW = [Math]::Round(($mgW+0.5), 0, [MidpointRounding]::ToEven)
    $mgH = [Math]::Round(($mgH+0.5), 0, [MidpointRounding]::ToEven)
    # 輸出視窗範圍
    $x2 = $Width
    $y2 = $Height - $star2
    $x1 = 0
    $y1 = [Math]::Round(($margin2+0.5), 0, [MidpointRounding]::ToEven)
    # 計算解度
    $w = $x2-$x1-$mgW
    $h = $y2-$y1-$mgH
    $w = [Math]::Round(($w-0.5), 0, [MidpointRounding]::ToEven)
    $h = [Math]::Round(($h-0.5), 0, [MidpointRounding]::ToEven)
    $rdp = New-RdpInfo '' $w $h $x1 $y1 $x2 $y2
    $rdp.Margin[0] = $mgW
    $rdp.Margin[1] = $mgH
    $rdp.Scaling = $Scaling
    return $rdp
}
```

## 測試出來2K的極限解析度
### 100%
RdoInfo: 2545 1512 0 8 2560 1560
edge   : 8
### 125%
RdoInfo: 2543 1493 0 10 2560 1550
edge   : 9
### 150%
RdoInfo: 2539 1474 0 10 2560 1540
edge   : 10
