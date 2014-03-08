; wintt -- Windows Time Tracker
; Program for logging open/close time of windows.
; Copyright (c) 2014, Cezary Salbut
; All rights reserved.

#include <Constants.au3>
#include <FileConstants.au3>
#include <WindowsConstants.au3>
#include <ScrollBarConstants.au3>
#include <GuiEdit.au3>

; Global variables
; -----------------------------------------------------------------------------
Global $bDbgEnabled = false

Local $logFileName = "wintt.txt"
Local $logFileHandle = 0
Local $WinMatchRule = " - Task"

; Program start
; -----------------------------------------------------------------------------
DbgInit()

Local $WinList[0]
Local $WinListPrev[1][1]

while 1

    $WinList = WinList($WinMatchRule)

    for $i = 1 to $WinList[0][0]
        local $win = $WinList[$i][1]
        local $winTitle = $WinList[$i][0]

        if isWinAppear($win, $WinList, $WinListPrev) then
            Print("Window appeared: " & $winTitle)
            LogWinEvent($winTitle, $logFileName, "[start]")
        endif
    next

    for $i = 1 to $WinListPrev[0][0]
        local $win = $WinListPrev[$i][1]
        local $winTitle = $WinListPrev[$i][0]

        if isWinDisappear($win, $WinList, $WinListPrev) then
            Print("Window disappeared: " & $winTitle)
            LogWinEvent($winTitle, $logFileName, "[stop] ")
        endif
    next

    sleep(5000)
    $WinListPrev = $WinList

wend


; Function definitions
; -----------------------------------------------------------------------------
func isWinExist($winHandle, $winList)

    for $i = 1 to $winList[0][0]
        if $winList[$i][1] == $winHandle then
            return true
        endif
    next

    return false
endfunc


func isWinAppear($win, $WinList, $WinListPrev)
    if (isWinExist($win, $WinList) and not isWinExist($win, $WinListPrev)) then
        return true
    else
        return false
    endif
endfunc


func isWinDisappear($win, $WinList, $WinListPrev)
    if (isWinExist($win, $WinListPrev) and not isWinExist($win, $WinList)) then
        return true
    else
        return false
    endif
endfunc


func LogWinEvent($winTitle, $logFileName, $eventType)
    $logFileHandle = FileOpen($logFileName, $FO_APPEND)
    FileWriteLine( $logFileHandle, Timestamp() & " " & $eventType & " " & $winTitle)
    FileClose($logFileHandle)
endfunc


func Timestamp()
    return @MDAY & "-" & @MON & "-" & @YEAR & " " & @HOUR & ":" & @MIN & ":" & @SEC
endfunc


func DbgInit()
    if $bDbgEnabled then
        Global $dbgGuiHandle = GUICreate("taskgrab debug", 600, 600, 900, 100)
        Global $hDbg = GUICtrlCreateEdit("", 0, 0, 600, 600, _
            $ES_AUTOVSCROLL + $ES_MULTILINE + $ES_READONLY + $WS_VSCROLL)
        GUISetState(@SW_SHOW)
    endif
endfunc


; Print a string to the debug console
func Print($sText)
    if $bDbgEnabled then
        $iEnd = StringLen(GUICtrlRead($hDbg))
        _GUICtrlEdit_SetSel($hDbg, $iEnd, $iEnd)
        _GUICtrlEdit_Scroll($hDbg, $SB_SCROLLCARET)
        GUICtrlSetData($hDbg, $sText & @CRLF, 1)
    endif
endfunc

