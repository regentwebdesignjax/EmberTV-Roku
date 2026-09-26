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

    m.messageGroup  = m.top.findNode("messageGroup")
    m.messageTitle  = m.top.findNode("messageTitle")
    m.messageDetail = m.top.findNode("messageDetail")

    if m.task <> invalid then m.task.observeField("response", "onTaskResponse")

    if m.grid <> invalid then
        m.grid.observeField("itemSelected", "onGridItemSelected")
        m.grid.observeField("itemFocused", "onGridItemFocused")
    end if

    m.top.observeField("reload", "onReloadChanged")
    m.top.observeField("visible", "onVisibleChanged")

    m._focusState = "grid"
    m._needsReload = false
    
    updateFocusVisuals()
end sub

' Called by MainScene when the OS warns we are near the memory limit. Only safe
' to call while this scene is hidden; onVisibleChanged refetches on return.
function releaseCachedContent(args as Dynamic) as Void
    if m.grid <> invalid and m.grid.content <> invalid then
        print "RentalsScene: releasing grid content"
        m.grid.content = invalid
        m._needsReload = true
    end if
end function

sub onVisibleChanged()
    if m.top.visible = true then
        ' Restore anything we gave back under memory pressure
        if m._needsReload = true then
            m._needsReload = false
            loadRentals()
        end if

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

sub onReloadChanged()
    if m.top.reload = true then loadRentals()
end sub

sub loadRentals()
    if m.task = invalid then return
    if m.grid = invalid or m.grid.content = invalid or m.grid.content.getChildCount() = 0 then
        showMessage("Loading your library...", "")
    end if
    m.task.request = { action: "library" }
    m.task.control = "RUN"
end sub

sub onTaskResponse()
    if m.task = invalid then return
    r = m.task.response
    if r = invalid then return

    if r.signedOut = true then
        m.top.signedOut = true
        return
    end if

    if r.ok <> true then
        err = r.error
        if err = invalid then err = ""
        ' Keep showing what we have; only an empty screen gets the error.
        if m.grid = invalid or m.grid.content = invalid or m.grid.content.getChildCount() = 0 then
            showMessage("Couldn't load your library", err)
            focusButtons()
        end if
        return
    end if

    c = m.task.content
    if c = invalid then return
    if m.grid <> invalid then
        m.grid.content = c
        m.grid.jumpToItem = 0
    end if
    m.top.library = c

    if c.getChildCount() = 0 then
        showMessage("Your library is empty", "Rentals on your Ember TV account will appear here.")
        if m.focusedTitle <> invalid then m.focusedTitle.text = ""
        focusButtons()
        return
    end if

    hideMessage()
    if m.top.visible = true and m._focusState = "grid" and m.grid <> invalid then
        m.grid.setFocus(true)
    end if
end sub

sub showMessage(title as String, detail as String)
    if m.messageGroup = invalid then return
    m.messageTitle.text = title
    m.messageDetail.text = detail
    m.messageGroup.visible = true
    if m.grid <> invalid then m.grid.visible = false
end sub

sub hideMessage()
    if m.messageGroup <> invalid then m.messageGroup.visible = false
    if m.grid <> invalid then m.grid.visible = true
end sub

' Nothing to select in the grid: park focus on Refresh.
sub focusButtons()
    if m._focusState <> "grid" then return
    m._focusState = "refresh"
    if m.top.visible = true and m.refreshBtn <> invalid then m.refreshBtn.setFocus(true)
    updateFocusVisuals()
end sub

function gridIsEmpty() as Boolean
    if m.grid = invalid or m.grid.content = invalid then return true
    return m.grid.content.getChildCount() = 0
end function

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
        if key = "down" and gridIsEmpty() then
            return true
        else if key = "down" then
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
        if key = "down" and gridIsEmpty() then
            return true
        else if key = "down" then
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