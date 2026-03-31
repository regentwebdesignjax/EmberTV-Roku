' components/RentalGridItem.brs

sub init()
    m.poster          = m.top.findNode("poster")
    m.expirationLabel = m.top.findNode("expirationLabel")
    m.focusRing       = m.top.findNode("focusRing")
    m.focusAnim       = m.top.findNode("focusAnim")
    m.scaleInterp     = m.top.findNode("scaleInterp")
end sub

sub onItemContentChanged()
    c = m.top.itemContent
    if c = invalid then return

    ' 1. Poster
    if m.poster <> invalid then
        if c.hdPosterUrl <> invalid and c.hdPosterUrl <> "" then
            m.poster.uri = c.hdPosterUrl
        else if c.poster <> invalid then
            m.poster.uri = c.poster
        else
            m.poster.uri = ""
        end if
    end if

    ' 2. Expiration Label
    if m.expirationLabel <> invalid then
        if c.description <> invalid and c.description <> "" then 
            m.expirationLabel.text = c.description 
        else 
            m.expirationLabel.text = "Available to watch"
        end if
    end if
end sub

sub onFocusPercentChanged()
    if m.focusRing = invalid then return
    
    ' Drive the animation frame based on the focus percent
    m.scaleInterp.fraction = m.top.focusPercent

    ' Show crisp border and turn text orange when item is focused
    if m.top.focusPercent > 0.5 then
        m.focusRing.visible = true
        m.expirationLabel.color = "0xEF6418FF" ' EmberTV Orange
    else
        m.focusRing.visible = false
        m.expirationLabel.color = "0xAAAAAAFF" ' Dimmed Grey
    end if
end sub