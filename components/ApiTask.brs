' components/ApiTask.brs

sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    req = m.top.request
    action = ""
    if req <> invalid and req.action <> invalid then action = req.action

    if action = "library" then
        result = EmberFetchLibrary()
        if result.content <> invalid then m.top.content = result.content
        m.top.response = { ok: result.ok, signedOut: result.signedOut, error: result.error }
    else if action = "playback" then
        m.top.response = EmberStartPlayback(req.filmId)
    else if action = "progress" then
        EmberReportProgress(req.filmId, req.seconds)
        m.top.response = { ok: true, signedOut: false, error: "" }
    else if action = "passwordSignIn" then
        result = EmberPasswordSignIn(req.email, req.password)
        m.top.response = { ok: result.ok, signedOut: false, error: result.error }
    else if action = "signOut" then
        EmberSignOut()
        m.top.response = { ok: true, signedOut: true, error: "" }
    else
        m.top.response = { ok: false, signedOut: false, error: "Unknown request." }
    end if
end sub
