' components/RentalsScene.brs

sub init()
    print "RentalsScene.init()"

    m.titleLabel = m.top.findNode("titleLabel")
    m.grid = m.top.findNode("grid")
    m.task = m.top.findNode("rentalsTask")

    m.refreshBtn   = m.top.findNode("refreshBtn")
    m.logoutBtn    = m.top.findNode("logoutBtn")
    
    m.refreshFill  = m.top.findNode("refreshFill")
    m.logoutFill   = m.top.findNode("logoutFill")
    m.refreshLabel = m.top.findNode("refreshLabel")
    m.logoutLabel  = m.top.findNode("logoutLabel")

    if m.task = invalid then print "RentalsScene: rentalsTask node NOT found"

    if m.grid <> invalid then
        m.grid.observeField("itemSelected", "onGridItemSelected")
    end if

    m.top.observeField("authToken", "onAuthTokenChanged")
    m.top.observeField("refreshNow", "onRefreshNowChanged")
    
    ' FIX: Observe visibility to restore focus automatically
    m.top.observeField("visible", "onVisibleChanged")

    m._lastToken = ""
    m._focusState = "grid"
    
    ' Initial visuals
    updateFocusVisuals()
end sub

' FIX: Ensure proper element gets focus when screen appears
sub onVisibleChanged()
    if m.top.visible = true then
        ' Restore focus to the last known state (defaulting to grid)
        if m._focusState = "refresh" then
            if m.refreshBtn <> invalid then m.refreshBtn.setFocus(true)
        else if m._focusState = "logout" then
            if m.logoutBtn <> invalid then m.logoutBtn.setFocus(true)
        else
            ' Default to Grid
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
    ' optional
end sub

sub onTaskContentChanged()
    if m.task = invalid then return
    c = m.task.content
    if c = invalid then return

    if m.grid <> invalid then
        m.grid.content = c
        m.grid.jumpToItem = 0
        ' Only set focus if we are currently visible and in grid mode
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

    ' Force change
    m.top.selectedRental = invalid
    m.top.selectedRental = item
end sub

' ---- FOCUS HANDLING ----

sub updateFocusVisuals()
    c_orange = "#EF6418"
    c_dark   = "#151515"
    c_white  = "#FFFFFF"
    c_black  = "#000000"

    ' Default: Dark bg, White text
    if m.refreshFill <> invalid then m.refreshFill.color = c_dark
    if m.refreshLabel <> invalid then m.refreshLabel.color = c_white
    if m.logoutFill <> invalid then m.logoutFill.color = c_dark
    if m.logoutLabel <> invalid then m.logoutLabel.color = c_white

    ' Highlight selected
    if m._focusState = "refresh" then
        if m.refreshFill <> invalid then m.refreshFill.color = c_orange
        if m.refreshLabel <> invalid then m.refreshLabel.color = c_black
    else if m._focusState = "logout" then
        if m.logoutFill <> invalid then m.logoutFill.color = c_orange
        if m.logoutLabel <> invalid then m.logoutLabel.color = c_black
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false

    if m._focusState = "grid" then
        ' Safety: If we think we are in grid mode, but grid lacks focus, force it.
        if m.grid <> invalid and not m.grid.hasFocus() then
            m.grid.setFocus(true)
        end if

        if key = "up" then
            ' Move to Refresh button
            currIdx = m.grid.itemFocused
            if currIdx < 6 then ' Only from top row
                m._focusState = "refresh"
                if m.refreshBtn <> invalid then m.refreshBtn.setFocus(true) 
                updateFocusVisuals()
                return true
            end if
        end if
        ' Allow Grid to handle everything else (Left/Right/Down)
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