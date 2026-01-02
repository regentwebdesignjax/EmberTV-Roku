' components/PlayerScene.brs

sub init()
    print "PlayerScene.init()"

    m.video = m.top.findNode("video")
    m.titleLabel = m.top.findNode("titleLabel")

    if m.video <> invalid then
        m.video.observeField("state", "onVideoStateChanged")
        m.video.observeField("position", "onVideoPositionChanged")
    end if

    m.top.observeField("content", "onContentChanged")
    m.top.observeField("visible", "onVisibleChanged")

    m._filmId = ""
    m._lastSavedSec = -999
end sub

sub onVisibleChanged()
    print "PlayerScene: visible="; m.top.visible
    if m.top.visible = true and m.video <> invalid then
        m.video.setFocus(true)
    end if
end sub

sub onContentChanged()
    c = m.top.content
    if c = invalid then return

    title = ""
    url = ""
    fmt = "hls"

    if c.Title <> invalid then title = c.Title
    if c.url <> invalid then url = c.url
    if c.streamFormat <> invalid and c.streamFormat <> "" then fmt = c.streamFormat

    if c.id <> invalid and c.id <> "" then
        m._filmId = c.id
    else
        m._filmId = title
    end if

    if m.titleLabel <> invalid then
        m.titleLabel.text = title
        m.titleLabel.visible = true
    end if

    if url = invalid or url = "" then
        print "PlayerScene: missing playback url"
        return
    end if

    videoContent = CreateObject("roSGNode", "ContentNode")
    videoContent.url = url
    videoContent.streamFormat = fmt

    if m.video <> invalid then
        m.video.control = "stop"
        m.video.content = videoContent
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

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false

    if key = "back" then
        print "PlayerScene: back pressed"
        if m.video <> invalid then m.video.control = "stop"

        ' Save a last checkpoint immediately (optional)
        if m.video <> invalid then
            p = int(m.video.position)
            if p > 0 then
                EmberSaveResumeSeconds(m._filmId, p)
                print "PlayerScene: saved resume at "; p
            end if
        end if

        m.top.backRequested = true
        return true
    end if

    return false
end function
