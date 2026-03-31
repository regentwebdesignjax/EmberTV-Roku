' components/RentalsScene.brs

sub init()
    m.titleLabel = m.top.findNode("titleLabel")
    m.grid = m.top.findNode("grid")
    m.task = m.top.findNode("rentalsTask")

    m.refreshBtn   = m.top.findNode("refreshBtn")
    m.logoutBtn    = m.top.findNode("logoutBtn")
    
    m.refreshFill  = m.top.findNode("refreshFill")
    m.logoutFill   = m.top.findNode("logoutFill")
    m.refreshLabel = m.top.findNode("refreshLabel")
    m.logoutLabel  = m.top.findNode("logoutLabel")
    
    m.focusedTitle = m.top.findNode("focusedTitle")

    if m.grid <> invalid then
        m.grid.observeField("itemSelected", "onGridItemSelected")
        m.grid.observeField("itemFocused", "onGridItemFocused")
    end if

    m.top.observeField("authToken", "onAuthTokenChanged")
    m.top.observeField("refreshNow", "onRefreshNowChanged")
    m.top.observeField("visible", "onVisibleChanged")

    m._lastToken = ""
    m._focusState = "grid"
    
    updateFocusVisuals()
end sub

sub onVisibleChanged()
    if m.top.visible = true then
        if m._focusState = "refresh" then
            if m.refreshBtn <> invalid then m.refreshBtn.setFocus(true)
        else if m._focusState = "logout" then
            if m.logoutBtn <> invalid then m.logoutBtn.setFocus(true)
        else
            if m.grid <> invalid then m.grid.setFocus(true)
        end if
        updateFocusVisuals()
    end if
end sub

sub onAuthTokenChanged()
    token = m.top.authToken
    if token = invalid then token = ""
    if token = "" then return
    if token = m._lastToken then return
    m._lastToken = token

    loadRentals()
end sub

sub onRefreshNowChanged()
    if m.top.refreshNow = true then
        m.top.refreshNow = false
        loadRentals()
    end if
end sub

sub loadRentals()
    if m.task = invalid then return
    m.task.observeField("status", "onTaskStatusChanged")
    m.task.observeField("content", "onTaskContentChanged")
    m.task.authToken = m.top.authToken
    m.task.control = "RUN"
end sub

sub onTaskStatusChanged()
end sub

sub onTaskContentChanged()
    if m.task = invalid then return
    c = m.task.content
    if c = invalid then return

    if m.grid <> invalid then
        m.grid.content = c
        m.grid.jumpToItem = 0
        if m.top.visible = true and m._focusState = "grid" then 
            m.grid.setFocus(true)
        end if
    end if
end sub

sub onGridItemSelected()
    if m.grid = invalid then return
    idx = m.grid.itemSelected
    if idx < 0 then return

    c = m.grid.content
    if c = invalid then return
    item = c.getChild(idx)
    if item = invalid then return

    m.top.selectedRental = invalid
    m.top.selectedRental = item
end sub

sub onGridItemFocused()
    if m.grid = invalid or m.focusedTitle = invalid then return
    
    idx = m.grid.itemFocused
    c = m.grid.content
    
    if c <> invalid and idx >= 0 and idx < c.getChildCount() then
        item = c.getChild(idx)
        if item <> invalid and item.Title <> invalid then
            ' Display the title of the highlighted item dynamically
            m.focusedTitle.text = item.Title
        end if
    end if
end sub

' ---- FOCUS HANDLING ----

sub updateFocusVisuals()
    c_unfocused_bg   = "0x2A2A2AFF" ' Dark Grey
    c_unfocused_text = "0xAAAAAAFF" ' Dim White
    c_focused_bg     = "0xEBEBEBFF" ' Light Grey Highlight
    c_focused_text   = "0x121212FF" ' Dark Text

    if m.refreshFill <> invalid then m.refreshFill.color = c_unfocused_bg
    if m.refreshLabel <> invalid then m.refreshLabel.color = c_unfocused_text
    if m.logoutFill <> invalid then m.logoutFill.color = c_unfocused_bg
    if m.logoutLabel <> invalid then m.logoutLabel.color = c_unfocused_text

    if m._focusState = "refresh" then
        if m.refreshFill <> invalid then m.refreshFill.color = c_focused_bg
        if m.refreshLabel <> invalid then m.refreshLabel.color = c_focused_text
    else if m._focusState = "logout" then
        if m.logoutFill <> invalid then m.logoutFill.color = c_focused_bg
        if m.logoutLabel <> invalid then m.logoutLabel.color = c_focused_text
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false

    if m._focusState = "grid" then
        if m.grid <> invalid and not m.grid.hasFocus() then
            m.grid.setFocus(true)
        end if

        if key = "up" then
            currIdx = m.grid.itemFocused
            if currIdx < 6 then ' Top row (6 columns)
                m._focusState = "refresh"
                if m.refreshBtn <> invalid then m.refreshBtn.setFocus(true) 
                updateFocusVisuals()
                return true
            end if
        end if
        return false

    else if m._focusState = "refresh" then
        if key = "down" then
            m._focusState = "grid"
            if m.grid <> invalid then m.grid.setFocus(true)
            updateFocusVisuals()
            return true
        else if key = "right" then
            m._focusState = "logout"
            if m.logoutBtn <> invalid then m.logoutBtn.setFocus(true)
            updateFocusVisuals()
            return true
        else if key = "OK" then
            loadRentals() 
            return true
        end if

    else if m._focusState = "logout" then
        if key = "down" then
            m._focusState = "grid"
            if m.grid <> invalid then m.grid.setFocus(true)
            updateFocusVisuals()
            return true
        else if key = "left" then
            m._focusState = "refresh"
            if m.refreshBtn <> invalid then m.refreshBtn.setFocus(true)
            updateFocusVisuals()
            return true
        else if key = "OK" then
            m.top.logoutRequested = true
            return true
        end if
    end if

    return false
end function