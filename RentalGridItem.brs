' components/RentalGridItem.brs

sub init()
    m.poster = m.top.findNode("poster")
    m.title  = m.top.findNode("titleLabel")
    m.meta   = m.top.findNode("metaLabel")
    
    ' The new Glow Group
    m.glow   = m.top.findNode("focusGlow")
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

    ' 2. Text Labels
    if m.title <> invalid then
        if c.Title <> invalid then m.title.text = c.Title else m.title.text = ""
    end if

    if m.meta <> invalid then
        txt = ""
        if c.year <> invalid then txt = c.year.ToStr()
        if c.genre <> invalid then
            if txt <> "" then txt = txt + " • "
            txt = txt + c.genre
        end if
        m.meta.text = txt
    end if
end sub

sub onFocusPercentChanged()
    if m.glow = invalid then return
    
    ' Show glow when item is focused
    if m.top.focusPercent > 0.5 then
        m.glow.visible = true
    else
        m.glow.visible = false
    end if
end sub