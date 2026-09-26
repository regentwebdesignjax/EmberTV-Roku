' components/PlayerScene.brs
'
' Plays a rental. Asks the server for a fresh signed stream URL (it checks
' the rental), then reports the position every 30 seconds, on pause, on
' Back and at the end, so the viewer can resume on any device.

sub init()
    m.video = m.top.findNode("video")
    m.titleLabel = m.top.findNode("titleLabel")
    m.messageGroup = m.top.findNode("messageGroup")
    m.messageTitle = m.top.findNode("messageTitle")
    m.messageDetail = m.top.findNode("messageDetail")
    m.heartbeat = m.top.findNode("heartbeat")

    ' Forces focus onto the video node a moment after the scene appears;
    ' without it the container can keep focus and the remote does nothing.
    m.focusTimer = CreateObject("roSGNode", "Timer")
    m.focusTimer.repeat = false
    m.focusTimer.duration = 0.1
    m.focusTimer.observeField("fire", "onFocusTimerFired")

    if m.video <> invalid then
        m.video.enableUI = true
        m.video.observeField("state", "onVideoStateChanged")
        m.video.observeField("errorCode", "onVideoError")
    end if
    if m.heartbeat <> invalid then m.heartbeat.observeField("fire", "onHeartbeat")

    m.top.observeField("content", "onContentChanged")
    m.top.observeField("visible", "onVisibleChanged")

    m._filmId = ""
    m._started = false
    m._finished = false
    m._playbackTask = invalid
    ' Keep references so running progress reports aren't collected mid-flight.
    m._progressTasks = []
end sub

sub onVisibleChanged()
    if m.top.visible = true then
        m.focusTimer.control = "start"
    else
        stopPlayback()
    end if
end sub

sub onFocusTimerFired()
    if m.top.visible = true and m.video <> invalid then m.video.setFocus(true)
end sub

sub onContentChanged()
    c = m.top.content
    if c = invalid then return

    stopPlayback()
    m._filmId = ""
    if c.hasField("filmId") and c.filmId <> invalid then m._filmId = c.filmId
    m._started = false
    m._finished = false

    if m.titleLabel <> invalid then
        m.titleLabel.text = c.title
        m.titleLabel.visible = true
    end if

    if m._filmId = "" then
        showMessage("This film can't be played right now.", "Press Back to return.")
        return
    end if

    showMessage("Loading...", "")
    m._playbackTask = CreateObject("roSGNode", "ApiTask")
    m._playbackTask.observeField("response", "onPlaybackResponse")
    m._playbackTask.request = { action: "playback", filmId: m._filmId }
    m._playbackTask.control = "RUN"
end sub

sub onPlaybackResponse()
    task = m._playbackTask
    if task = invalid then return
    m._playbackTask = invalid
    r = task.response
    if r = invalid then return
    if m.top.visible <> true then return

    if r.signedOut = true then
        m.top.signedOut = true
        return
    end if
    if r.ok <> true or r.url = invalid or r.url = "" then
        err = r.error
        if err = invalid or err = "" then err = "This film can't be played right now."
        showMessage(err, "Press Back to return.")
        return
    end if

    c = m.top.content
    startAt = 0
    if c <> invalid and c.hasField("startAt") and c.startAt <> invalid then startAt = c.startAt

    stream = CreateObject("roSGNode", "ContentNode")
    stream.url = r.url
    stream.streamFormat = "hls"
    stream.title = c.title
    if startAt > 0 then stream.playStart = startAt * 1.0

    hideMessage()
    if m.video <> invalid then
        m.video.content = stream
        m.video.setFocus(true)
        m.video.control = "play"
    end if
    m._started = true
    if m.heartbeat <> invalid then m.heartbeat.control = "start"
end sub

sub onVideoError()
    if m.video = invalid then return
    print "PLAYER ERROR: "; m.video.errorCode; " - "; m.video.errorMsg
    if m.heartbeat <> invalid then m.heartbeat.control = "stop"
    showMessage("Playback stopped. Please try again.", "Press Back to return.")
end sub

sub onVideoStateChanged()
    if m.video = invalid then return
    state = m.video.state

    if state = "playing" or state = "buffering" then
        if m.titleLabel <> invalid then m.titleLabel.visible = false
    else if state = "paused" then
        ' Paused by the viewer: save the spot now.
        reportProgress(currentSeconds())
    else if state = "finished" then
        m._finished = true
        if m.heartbeat <> invalid then m.heartbeat.control = "stop"
        reportProgress(0)
        m._started = false
        m.top.backRequested = true
    end if
end sub

sub onHeartbeat()
    if m.video <> invalid and m.video.state = "playing" then reportProgress(currentSeconds())
end sub

function currentSeconds() as Integer
    if m.video = invalid then return 0
    p = Int(m.video.position)
    if p < 0 then p = 0
    return p
end function

sub reportProgress(seconds as Integer)
    if m._filmId = "" then return
    t = CreateObject("roSGNode", "ApiTask")
    t.request = { action: "progress", filmId: m._filmId, seconds: seconds }
    t.control = "RUN"
    m._progressTasks.push(t)
    if m._progressTasks.count() > 4 then m._progressTasks.shift()
end sub

' Stops the video and, if it was playing, saves where the viewer stopped.
sub stopPlayback()
    if m.heartbeat <> invalid then m.heartbeat.control = "stop"
    if m._playbackTask <> invalid then
        m._playbackTask.unobserveField("response")
        m._playbackTask = invalid
    end if
    if m._started and not m._finished then reportProgress(currentSeconds())
    m._started = false
    if m.video <> invalid then m.video.control = "stop"
end sub

sub showMessage(title as String, detail as String)
    if m.messageGroup = invalid then return
    m.messageTitle.text = title
    m.messageDetail.text = detail
    m.messageGroup.visible = true
end sub

sub hideMessage()
    if m.messageGroup <> invalid then m.messageGroup.visible = false
end sub

' Catches the remote when focus has slipped off the video node.
function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false

    if key = "back" then
        stopPlayback()
        m.top.backRequested = true
        return true
    end if

    if m.video <> invalid and m._started then
        if key = "play" then
            if m.video.state = "playing" then
                m.video.control = "pause"
            else
                m.video.control = "resume"
            end if
            return true
        else if key = "left" or key = "right" or key = "fastforward" or key = "rewind" then
            ' Let the video node's own trick-play UI handle seeking.
            m.video.setFocus(true)
            return false
        end if
    end if

    return false
end function
