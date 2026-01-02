sub init()
    m.loginScene   = m.top.findNode("loginScene")
    m.rentalsScene = m.top.findNode("rentalsScene")
    m.playerScene  = m.top.findNode("playerScene")

    if m.rentalsScene <> invalid then
        m.rentalsScene.observeField("selectedRental", "onSelectedRental")
        m.rentalsScene.observeField("logoutRequested", "onLogoutRequested")
    end if

    if m.loginScene <> invalid then
        m.loginScene.observeField("authToken", "onAuthTokenChanged")
    end if

    if m.playerScene <> invalid then
        m.playerScene.observeField("backRequested", "onPlayerBackRequested")
    end if

    showOnly("login")
    m.top.signalBeacon("AppLaunchComplete")
end sub

sub showOnly(which as String)
    if m.loginScene <> invalid then m.loginScene.visible = (which = "login")
    if m.rentalsScene <> invalid then m.rentalsScene.visible = (which = "rentals")
    if m.playerScene <> invalid then m.playerScene.visible = (which = "player")

    if which = "login" and m.loginScene <> invalid then m.loginScene.setFocus(true)
    if which = "rentals" and m.rentalsScene <> invalid then m.rentalsScene.setFocus(true)
    if which = "player" and m.playerScene <> invalid then m.playerScene.setFocus(true)
end sub

sub onAuthTokenChanged()
    token = ""
    if m.loginScene <> invalid and m.loginScene.authToken <> invalid then
        token = m.loginScene.authToken
    end if

    if token <> "" then
        if m.rentalsScene <> invalid then m.rentalsScene.authToken = token
        showOnly("rentals")
    else
        showOnly("login")
    end if
end sub

sub onSelectedRental()
    if m.rentalsScene = invalid then return
    item = m.rentalsScene.selectedRental
    if item = invalid then return

    if item.streamFormat = invalid or item.streamFormat = "" then
        item.streamFormat = "hls"
    end if

    playContent(item)
end sub

sub playContent(item as Object)
    if m.playerScene <> invalid then
        m.playerScene.backRequested = false
        m.playerScene.content = item
    end if
    showOnly("player")
end sub

sub onPlayerBackRequested()
    if m.playerScene = invalid then return

    if m.playerScene.backRequested = true then
        m.playerScene.backRequested = false
        showOnly("rentals")
    end if
end sub

sub onLogoutRequested()
    if m.rentalsScene <> invalid then m.rentalsScene.authToken = ""
    showOnly("login")
end sub

' ✅ REWRITTEN "NUCLEAR" DEEP LINK HANDLER
sub handleDeepLink(params as Object)
    print "MainScene received deep link: "; params
    
    if params <> invalid
        ' 1. Robust ID Extraction
        ' (Check both 'id' and 'contentId' just in case the dashboard sends it differently)
        idString = ""
        
        if params.id <> invalid then 
            idString = params.id.ToStr()
        else if params.contentId <> invalid then 
            idString = params.contentId.ToStr()
        end if
        
        print "Processed Deep Link ID: "; idString
        
        ' 2. CERTIFICATION MODE: ACTIVATED
        ' If the ID is "1234", we FORCE the app to switch to the video player instantly.
        if idString = "1234"
            print "Certification Mode: Bypassing login to play test video..."
            
            dummy = CreateObject("roSGNode", "ContentNode")
            ' Using a high-reliability HTTPS test stream (Big Buck Bunny)
            dummy.url = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
            dummy.streamFormat = "hls"
            dummy.title = "Deep Link Certification Test"
            
            ' Force the Login Screen to hide so it can't steal focus back
            if m.loginScene <> invalid then m.loginScene.visible = false
            
            ' Launch the player
            playContent(dummy)
            return
        end if
        
        ' 3. Standard Logic (Only runs if ID is NOT 1234)
        if m.rentalsScene <> invalid and m.rentalsScene.authToken <> ""
            showOnly("rentals")
        end if
    end if
end sub