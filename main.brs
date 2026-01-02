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

    ' Handle Deep Linking at startup
    if args <> invalid and args.contentId <> invalid and args.mediaType <> invalid
        print "Deep Linking launch: "; args.contentId
        inputData = { id: args.contentId, type: args.mediaType }
        scene.callFunc("handleDeepLink", inputData)
    end if
    
    ' Signal the beacon (Performance requirement)
    scene.signalBeacon("AppLaunchComplete")

    while true
        msg = wait(0, m.port)
        
        if type(msg) = "roSGScreenEvent"
            if msg.isScreenClosed() then return
            
        ' Handle Input Events
        else if type(msg) = "roInputEvent"
            if msg.isInput()
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