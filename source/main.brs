sub Main(args as Dynamic)
    print "Main() started"

    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Create the input object to listen for voice/deep links
    input = CreateObject("roInput")
    input.setMessagePort(m.port)

    scene = screen.CreateScene("MainScene")
    screen.Show()

    ' Handle launch reason — Instant Resume vs normal/deep-link launch
    if args <> invalid and args.reason = "instant_resume"
        print "Instant Resume launch"
        scene.callFunc("handleInstantResume", {})
    else
        ' Handle Deep Linking at startup
        if args <> invalid and args.contentId <> invalid and args.mediaType <> invalid
            print "Deep Linking launch: "; args.contentId
            inputData = { id: args.contentId, type: args.mediaType }
            scene.callFunc("handleDeepLink", inputData)
        end if
        ' Signal the beacon (Performance requirement)
        scene.signalBeacon("AppLaunchComplete")
    end if

    while true
        msg = wait(0, m.port)
        
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
            
        ' Handle Input Events
        else if type(msg) = "roInputEvent"
            if msg.isInstantResume()
                print "Instant Resume event"
                scene.callFunc("handleInstantResume", {})
            else if msg.isInput()
                info = msg.getInfo()
                if info.contentId <> invalid and info.mediaType <> invalid
                    print "Deep Linking event: "; info.contentId
                    inputData = { id: info.contentId, type: info.mediaType }
                    scene.callFunc("handleDeepLink", inputData)
                end if
            end if
        end if
    end while
end sub