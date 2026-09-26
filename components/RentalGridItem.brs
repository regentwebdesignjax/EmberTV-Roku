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

    ' Ended rentals and upcoming screenings are shown dimmed.
    if m.poster <> invalid then
        m.poster.opacity = 1.0
        if c.hasField("watchable") and c.watchable = false then m.poster.opacity = 0.4
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

sub onFocusChanged()
    if m.focusRing = invalid then return

    ' Only the poster the viewer is on, and only while the grid has focus
    ' (not while they're on Refresh or Sign Out).
    fraction = m.top.focusPercent
    if m.top.gridHasFocus <> true then fraction = 0
    if m.scaleInterp <> invalid then m.scaleInterp.fraction = fraction

    if fraction > 0.5 then
        m.focusRing.visible = true
        m.expirationLabel.color = "0xEF6418FF" ' Ember TV orange
    else
        m.focusRing.visible = false
        m.expirationLabel.color = "0xAAAAAAFF"
    end if
end sub
