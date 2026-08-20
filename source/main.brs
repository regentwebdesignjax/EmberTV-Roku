sub Main(args as Dynamic)
    print "Main() started"

    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.setMessagePort(m.port)

    ' Create the input object to listen for voice/deep links
    input = CreateObject("roInput")
    input.setMessagePort(m.port)

    ' Subscribe to per-app low-memory warnings (required for certification)
    m.memoryMonitor = CreateObject("roAppMemoryMonitor")
    if m.memoryMonitor <> invalid
        m.memoryMonitor.setMessagePort(m.port)
        m.memoryMonitor.enableMemoryWarningEvent(true)
        print "Memory: available(kb)="; m.memoryMonitor.GetChannelAvailableMemory()
        print "Memory: limitPercent="; m.memoryMonitor.GetMemoryLimitPercent()
        limits = m.memoryMonitor.GetChannelMemoryLimit()
        if limits <> invalid then print "Memory: limits="; FormatJSON(limits)
    end if

    ' Subscribe to system-wide low-memory notifications (required for certification)
    m.deviceInfo = CreateObject("roDeviceInfo")
    if m.deviceInfo <> invalid
        m.deviceInfo.setMessagePort(m.port)
        m.deviceInfo.EnableLowGeneralMemoryEvent(true)
    end if

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
        ' AppLaunchComplete is signaled by MainScene.init() -- signaling it here
        ' too produced an "already signaled" warning on the console.
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

        ' Handle low-memory warnings
        else if type(msg) = "roAppMemoryNotificationEvent"
            percent = -1
            try
                percent = msg.getUsagePercentage()
            catch e
                print "Memory event: could not read usage percentage"
            end try
            print "Low memory warning at "; percent; "% of app limit"
            scene.callFunc("handleLowMemory", { percent: percent })

        ' Handle system-wide low-memory notifications
        else if type(msg) = "roDeviceInfoEvent"
            dinfo = msg.getInfo()
            if dinfo <> invalid and dinfo.generalMemoryLevel <> invalid
                print "General memory level: "; dinfo.generalMemoryLevel
                if dinfo.generalMemoryLevel <> "normal"
                    scene.callFunc("handleLowMemory", { level: dinfo.generalMemoryLevel })
                end if
            end if
        end if
    end while
end sub