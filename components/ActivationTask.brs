' components/ActivationTask.brs

sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    m.top.status = "starting"
    cfg = EmberConfig()

    while not m.top.cancel
        start = EmberStartActivation()
        if m.top.cancel then return
        if not start.ok then
            m.top.error = start.error
            m.top.status = "error"
            return
        end if

        m.top.code = {
            userCode: start.userCode
            qrUrl: cfg.apiBaseUrl + "v2/device/qr.png?code=" + start.userCode
        }
        m.top.status = "waiting"

        deadline = EmberNow() + start.expiresIn
        interval = start.interval
        while true
            ' Sleep in short slices so a cancel stops us promptly.
            waited = 0
            while waited < interval * 1000
                if m.top.cancel then return
                sleep(250)
                waited = waited + 250
            end while
            if EmberNow() >= deadline then exit while

            poll = EmberPollActivation(start.deviceCode)
            if m.top.cancel then return
            if poll.result = "approved" then
                m.top.status = "approved"
                return
            else if poll.result = "restart" then
                exit while
            else if poll.result = "error" then
                m.top.error = poll.error
                m.top.status = "error"
                return
            end if
            interval = poll.interval
        end while
    end while
end sub
