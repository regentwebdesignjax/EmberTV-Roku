' components/LoginTask.brs

sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    m.top.status = "loading"
    m.top.error = ""
    m.top.token = ""

    email = m.top.email
    pass  = m.top.password

    api = EmberAPIClient()
    
    ' FIX: Removed incorrect first argument 'api'
    resp = api.login(email, pass)

    if resp = invalid or resp.ok <> true then
        m.top.status = "error"
        m.top.error = "Invalid email or password."
        if resp <> invalid and resp.error <> invalid then m.top.error = resp.error
        return
    end if

    m.top.token = resp.token
    m.top.status = "success"
end sub