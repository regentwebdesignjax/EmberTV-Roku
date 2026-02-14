' components/PlayerScene.brs

sub init()
    print "PlayerScene.init()"

    m.video = m.top.findNode("video")
    m.titleLabel = m.top.findNode("titleLabel")

    ' Create a Timer to force focus (The "Focus Fixer")
    m.focusTimer = CreateObject("roSGNode", "Timer")
    m.focusTimer.repeat = false
    m.focusTimer.duration = 0.1 ' 100ms delay
    m.focusTimer.observeField("fire", "onFocusTimerFired")

    if m.video <> invalid then
        ' Enable UI (Progress Bar, etc)
        m.video.enableUI = true
        
        m.video.observeField("state", "onVideoStateChanged")
        m.video.observeField("position", "onVideoPositionChanged")
        m.video.observeField("errorCode", "onVideoError")
    end if

    m.top.observeField("content", "onContentChanged")
    m.top.observeField("visible", "onVisibleChanged")

    m._filmId = ""
    m._lastSavedSec = -999
end sub

sub onVisibleChanged()
    print "PlayerScene: visible="; m.top.visible
    ' When screen becomes visible, start the timer to force focus
    if m.top.visible = true then
        m.focusTimer.control = "start"
    end if
end sub

sub onFocusTimerFired()
    ' The timer forces focus to the video node a split second after loading.
    ' This fixes the issue where the container steals focus from the player.
    if m.top.visible = true and m.video <> invalid then
        print "PlayerScene: Forcing focus to VIDEO node"
        m.video.setFocus(true)
    end if
end sub

sub onContentChanged()
    c = m.top.content
    if c = invalid then return

    print "PlayerScene: Content Set. URL="; c.url

    ' Extract ID for Resume logic
    if c.id <> invalid and c.id <> "" then
        m._filmId = c.id
    else
        m._filmId = c.Title
    end if

    if m.titleLabel <> invalid then
        m.titleLabel.text = c.Title
        m.titleLabel.visible = true
    end if

    if c.url = invalid or c.url = "" then
        print "PlayerScene: missing playback url"
        return
    end if

    if m.video <> invalid then
        m.video.control = "stop"
        m.video.content = c
        
        ' Attempt immediate focus
        m.video.setFocus(true)

        resumeSec = EmberLoadResumeSeconds(m._filmId)
        if resumeSec > 0 then
            print "PlayerScene: resuming at "; resumeSec
            m.video.seek = resumeSec
        end if

        m.video.control = "play"
        print "PlayerScene: control=play"
    end if
end sub

sub onVideoError()
    if m.video = invalid then return
    print "PLAYER ERROR: " + m.video.errorCode.ToStr() + " - " + m.video.errorMsg
end sub

sub onVideoStateChanged()
    if m.video = invalid then return
    print "PlayerScene: video state="; m.video.state

    if m.video.state = "playing" or m.video.state = "buffering" then
        if m.titleLabel <> invalid then m.titleLabel.visible = false
    end if

    if m.video.state = "finished" then
        EmberClearResume(m._filmId)
        m._lastSavedSec = -999
        m.top.backRequested = true
    end if
end sub

sub onVideoPositionChanged()
    if m.video = invalid then return
    if m._filmId = invalid or m._filmId = "" then return

    p = int(m.video.position)
    if p <= 0 then return

    if abs(p - m._lastSavedSec) >= 10 then
        EmberSaveResumeSeconds(m._filmId, p)
        m._lastSavedSec = p
    end if
end sub

' FIX: Manual Key Handler
' If the focus is slightly off, this catches the remote buttons and
' forces the video player to obey them.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false

    if key = "back" then
        print "PlayerScene: back pressed (Manual Capture)"
        if m.video <> invalid then m.video.control = "stop"
        
        ' Save resume point
        if m.video <> invalid then
            p = int(m.video.position)
            if p > 0 then EmberSaveResumeSeconds(m._filmId, p)
        end if

        m.top.backRequested = true
        return true
    end if

    if m.video <> invalid then
        if key = "play" then
            if m.video.state = "playing" then
                m.video.control = "pause"
            else
                m.video.control = "play"
            end if
            return true
        else if key = "fastforward" then
            m.video.control = "fastforward"
            return true
        else if key = "rewind" then
            m.video.control = "rewind"
            return true
        else if key = "left" or key = "right" then
            ' Let the video node handle seeking naturally if it has focus.
            ' But if we are here, we might need to force focus again.
            m.video.setFocus(true)
            return false 
        end if
    end if

    return false
end function