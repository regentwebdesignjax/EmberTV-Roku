' source/emberApi.brs
'
' Talks to the Ember TV API v2 (the web app's /v2 routes). Sign-in is by
' activation code: the TV shows a short code, the viewer approves it at
' app.emberstreaming.com/activate, and the TV receives a normal session
' (access + refresh token) that it keeps in the registry and refreshes.
'
' Everything here makes blocking network calls, so it runs only inside Task
' nodes (ApiTask, ActivationTask), never on the render thread -- except the
' registry helpers, which are safe anywhere.

' True when this channel was packaged by tools/make-staging-zip.sh, which adds
' ember_env=staging to the manifest. The manifest in the repo has no such key,
' so store builds always talk to production.
function EmberIsStaging() as Boolean
    return CreateObject("roAppInfo").GetValue("ember_env") = "staging"
end function

function EmberConfig() as Object
    if EmberIsStaging() then
        ' Staging site and Supabase project; rentals are paid with Stripe test cards.
        return {
            apiBaseUrl: "https://staging--embertv.netlify.app/"
            supabaseUrl: "https://tfnyowkprvmmkyckipya.supabase.co/"
            supabaseKey: "sb_publishable_P8c7Sb8DX51GiTuWA6GEPA_0XB-WrIu"
            client: "roku"
            websiteDisplayName: "staging--embertv.netlify.app"
        }
    end if
    return {
        ' The Ember TV web app. Every /v2 route lives under it.
        apiBaseUrl: "https://app.emberstreaming.com/"
        ' Supabase project, used only to refresh and end the sign-in session
        ' (sign-in itself goes through the web app).
        supabaseUrl: "https://bqdoxfeuhfzljvddpjbd.supabase.co/"
        ' Publishable key: public by design (the website ships the same one).
        supabaseKey: "sb_publishable_dDyGlDF2w0gvX1bJbz_knw_xVt4U6Lp"
        ' Sent as `client` on activation, playback and progress.
        client: "roku"
        ' Shown on screen, so no scheme.
        websiteDisplayName: "app.emberstreaming.com"
    }
end function

' ---- Registry: session and device id ----

function EmberSessionSection() as Object
    return CreateObject("roRegistrySection", "EmberSession")
end function

' The stored session, or invalid when signed out.
function EmberLoadSession() as Dynamic
    sec = EmberSessionSection()
    if not sec.Exists("access") or not sec.Exists("refresh") then return invalid
    expiresAt = 0
    if sec.Exists("expiresAt") then expiresAt = Val(sec.Read("expiresAt"))
    return { access: sec.Read("access"), refresh: sec.Read("refresh"), expiresAt: expiresAt }
end function

function EmberHasSession() as Boolean
    return EmberLoadSession() <> invalid
end function

sub EmberStoreSession(access as String, refresh as String, expiresIn as Dynamic)
    seconds = 3600
    if expiresIn <> invalid then seconds = Int(expiresIn)
    sec = EmberSessionSection()
    sec.Write("access", access)
    sec.Write("refresh", refresh)
    sec.Write("expiresAt", (EmberNow() + seconds).ToStr())
    sec.Flush()
end sub

sub EmberClearSession()
    sec = EmberSessionSection()
    sec.Delete("access")
    sec.Delete("refresh")
    sec.Delete("expiresAt")
    sec.Flush()
end sub

' Stable per install; identifies this Roku for playback and resume.
function EmberDeviceId() as String
    sec = CreateObject("roRegistrySection", "EmberDevice")
    if sec.Exists("id") then return sec.Read("id")
    id = CreateObject("roDeviceInfo").GetRandomUUID()
    sec.Write("id", id)
    sec.Flush()
    return id
end function

' Sign-in token and local resume points from the old Base44 channel.
sub EmberClearLegacyState()
    reg = CreateObject("roRegistry")
    reg.Delete("EmberAuth")
    reg.Delete("EmberResume")
    reg.Flush()
end sub

' A string field from parsed JSON, or "" when missing or not a string.
' (Comparing invalid with a string is a runtime error in BrightScript.)
function EmberStr(value as Dynamic) as String
    if value = invalid then return ""
    if type(value) <> "roString" and type(value) <> "String" then return ""
    return value
end function

' ---- Time ----

function EmberNow() as Integer
    return CreateObject("roDateTime").AsSeconds()
end function

' Seconds since the epoch for an API timestamp ("2026-09-25T04:00:00Z",
' "...00.123Z" or "...00.123456+00:00"; always UTC), or 0 when missing.
function EmberParseTime(value as Dynamic) as Integer
    if value = invalid then return 0
    if type(value) <> "roString" and type(value) <> "String" then return 0
    s = value.Replace(" ", "T")
    if Len(s) < 19 then return 0
    dt = CreateObject("roDateTime")
    dt.FromISO8601String(Left(s, 19))
    return dt.AsSeconds()
end function

' 4210 -> "1:10:10", 250 -> "4:10"
function EmberFormatClock(seconds as Integer) as String
    h = Int(seconds / 3600)
    mins = Int((seconds mod 3600) / 60)
    secs = seconds mod 60
    ss = secs.ToStr()
    if secs < 10 then ss = "0" + ss
    if h > 0 then
        mm = mins.ToStr()
        if mins < 10 then mm = "0" + mm
        return h.ToStr() + ":" + mm + ":" + ss
    end if
    return mins.ToStr() + ":" + ss
end function

' ---- HTTP ----

' { status: Integer (<= 0 when the network failed), data: parsed JSON or invalid }
function EmberHttp(method as String, url as String, body as Dynamic, headers as Object) as Object
    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.RetainBodyOnError(true)
    xfer.EnableEncodings(true)
    xfer.AddHeader("Accept", "application/json")
    for each key in headers
        xfer.AddHeader(key, headers[key])
    end for

    port = CreateObject("roMessagePort")
    xfer.SetMessagePort(port)

    started = false
    if method = "POST" then
        xfer.AddHeader("Content-Type", "application/json")
        payload = "{}"
        if body <> invalid then payload = FormatJson(body)
        started = xfer.AsyncPostFromString(payload)
    else
        started = xfer.AsyncGetToString()
    end if

    status = -1
    text = ""
    if started then
        msg = wait(15000, port)
        if type(msg) = "roUrlEvent" then
            status = msg.GetResponseCode()
            text = msg.GetString()
        else
            xfer.AsyncCancel()
        end if
    end if

    data = invalid
    if text <> "" then data = ParseJson(text)
    return { status: status, data: data }
end function

' A message to show for a failed response: the API's own message when it
' sent one ({ error: { code, message } }), else [fallback].
function EmberErrorMessage(resp as Object, fallback as String) as String
    if resp.status <= 0 then
        return "Can't reach Ember TV. Check your internet connection and try again."
    end if
    data = resp.data
    if type(data) = "roAssociativeArray" then
        err = data.error
        if type(err) = "roAssociativeArray" and err.message <> invalid then return err.message
    end if
    return fallback
end function

' ---- Activation (sign in with a code) ----

' { ok, deviceCode, userCode, expiresIn, interval } or { ok: false, error }
function EmberStartActivation() as Object
    cfg = EmberConfig()
    resp = EmberHttp("POST", cfg.apiBaseUrl + "v2/device/code", { client: cfg.client, device_id: EmberDeviceId() }, {})
    data = resp.data
    if resp.status = 200 and type(data) = "roAssociativeArray" and data.device_code <> invalid and data.user_code <> invalid then
        expiresIn = 600
        if data.expires_in <> invalid then expiresIn = Int(data.expires_in)
        interval = 5
        if data.interval <> invalid then interval = Int(data.interval)
        if interval < 1 then interval = 1
        return { ok: true, deviceCode: data.device_code, userCode: data.user_code, expiresIn: expiresIn, interval: interval, error: "" }
    end if
    return { ok: false, error: EmberErrorMessage(resp, "Couldn't get a sign-in code. Please try again.") }
end function

' { result: "approved" | "pending" | "restart" | "error", interval, error }
function EmberPollActivation(deviceCode as String) as Object
    cfg = EmberConfig()
    resp = EmberHttp("POST", cfg.apiBaseUrl + "v2/device/token", { device_code: deviceCode }, {})
    data = resp.data
    if resp.status = 200 and type(data) = "roAssociativeArray" then
        if data.access_token <> invalid and data.refresh_token <> invalid then
            EmberStoreSession(data.access_token, data.refresh_token, data.expires_in)
            return { result: "approved", interval: 0, error: "" }
        end if
    end if
    if resp.status = 202 then
        interval = 5
        if type(data) = "roAssociativeArray" and data.interval <> invalid then interval = Int(data.interval)
        if interval < 1 then interval = 1
        return { result: "pending", interval: interval, error: "" }
    end if
    ' Expired, already used or unknown: get a new code.
    if resp.status = 400 or resp.status = 409 or resp.status = 410 then
        return { result: "restart", interval: 0, error: "" }
    end if
    ' A blip on the network: keep the code and poll again.
    if resp.status <= 0 then return { result: "pending", interval: 5, error: "" }
    return { result: "error", interval: 0, error: EmberErrorMessage(resp, "Sign-in failed. Please try again.") }
end function

' ---- Email and password (for viewers who'd rather type) ----

' Through the web app, not Supabase Auth directly: Supabase now requires a
' CAPTCHA for password sign-ins, which a TV can't show. /v2/auth/password
' checks the password the same way, with rate limits instead of a CAPTCHA,
' and answers with an ordinary session.
' { ok, error }
function EmberPasswordSignIn(email as String, password as String) as Object
    cfg = EmberConfig()
    resp = EmberHttp("POST", cfg.apiBaseUrl + "v2/auth/password", { email: email, password: password }, {})
    data = resp.data
    if resp.status = 200 and type(data) = "roAssociativeArray" then
        if data.access_token <> invalid and data.refresh_token <> invalid then
            EmberStoreSession(data.access_token, data.refresh_token, data.expires_in)
            return { ok: true, error: "" }
        end if
    end if
    if resp.status = 400 or resp.status = 401 then
        return { ok: false, error: "That email and password don't match an Ember TV account." }
    end if
    ' Suspended, unconfirmed or too many tries: the server's message says what to do.
    if resp.status = 403 or resp.status = 429 then
        return { ok: false, error: EmberErrorMessage(resp, "Sign-in failed. Please try again in a moment.") }
    end if
    if resp.status <= 0 then return { ok: false, error: EmberErrorMessage(resp, "") }
    return { ok: false, error: "Sign-in failed. Please try again in a moment." }
end function

' ---- Session ----

' { ok, token, refresh, signedOut, error }
function EmberValidAccess() as Object
    s = EmberLoadSession()
    if s = invalid then return { ok: false, token: "", refresh: "", signedOut: true, error: "Please sign in again." }
    if s.expiresAt - EmberNow() > 60 then
        return { ok: true, token: s.access, refresh: s.refresh, signedOut: false, error: "" }
    end if
    return EmberRefresh(s.refresh)
end function

' Refreshes unless another task already did (the stored refresh token no
' longer matches the one we used). Supabase rotates refresh tokens.
function EmberRefresh(usedRefresh as String) as Object
    s = EmberLoadSession()
    if s = invalid then return { ok: false, token: "", refresh: "", signedOut: true, error: "Please sign in again." }
    if s.refresh <> usedRefresh then
        return { ok: true, token: s.access, refresh: s.refresh, signedOut: false, error: "" }
    end if

    cfg = EmberConfig()
    resp = EmberHttp("POST", cfg.supabaseUrl + "auth/v1/token?grant_type=refresh_token", { refresh_token: s.refresh }, { apikey: cfg.supabaseKey })
    data = resp.data
    if resp.status = 200 and type(data) = "roAssociativeArray" then
        if data.access_token <> invalid and data.refresh_token <> invalid then
            EmberStoreSession(data.access_token, data.refresh_token, data.expires_in)
            return { ok: true, token: data.access_token, refresh: data.refresh_token, signedOut: false, error: "" }
        end if
    end if
    ' Revoked or expired: sign in again. Offline: keep the session for later.
    if resp.status = 400 or resp.status = 401 or resp.status = 403 then
        EmberClearSession()
        return { ok: false, token: "", refresh: "", signedOut: true, error: "Please sign in again." }
    end if
    return { ok: false, token: "", refresh: "", signedOut: false, error: EmberErrorMessage(resp, "Something went wrong. Please try again in a moment.") }
end function

' Sends with the access token; on a 401, refreshes once and retries.
' { status, data, signedOut }
function EmberAuthorized(method as String, path as String, body as Dynamic) as Object
    auth = EmberValidAccess()
    if not auth.ok then return EmberAuthFailure(auth)

    url = EmberConfig().apiBaseUrl + path
    first = EmberHttp(method, url, body, { Authorization: "Bearer " + auth.token })
    if first.status <> 401 then return { status: first.status, data: first.data, signedOut: false }

    fresh = EmberRefresh(auth.refresh)
    if not fresh.ok then return EmberAuthFailure(fresh)
    second = EmberHttp(method, url, body, { Authorization: "Bearer " + fresh.token })
    if second.status = 401 then
        EmberClearSession()
        return { status: 401, data: second.data, signedOut: true }
    end if
    return { status: second.status, data: second.data, signedOut: false }
end function

function EmberAuthFailure(auth as Object) as Object
    if auth.signedOut then return { status: 401, data: invalid, signedOut: true }
    return { status: -1, data: invalid, signedOut: false }
end function

' Best effort: revoke this Roku's refresh token, then forget the session.
sub EmberSignOut()
    s = EmberLoadSession()
    if s <> invalid then
        cfg = EmberConfig()
        EmberHttp("POST", cfg.supabaseUrl + "auth/v1/logout?scope=local", {}, { apikey: cfg.supabaseKey, Authorization: "Bearer " + s.access })
    end if
    EmberClearSession()
end sub

' ---- Library ----

' { ok, signedOut, error, content } where content is a ContentNode whose
' children are the rentals, newest expiry first.
function EmberFetchLibrary() as Object
    resp = EmberAuthorized("GET", "v2/library", invalid)
    if resp.signedOut then return { ok: false, signedOut: true, error: "Please sign in again.", content: invalid }
    data = resp.data
    if resp.status <> 200 or type(data) <> "roAssociativeArray" then
        return { ok: false, signedOut: false, error: EmberErrorMessage(resp, "Couldn't load your library."), content: invalid }
    end if

    items = data.items
    if type(items) <> "roArray" then items = []
    now = EmberNow()

    root = CreateObject("roSGNode", "ContentNode")
    for each row in items
        if type(row) <> "roAssociativeArray" then continue for
        ent = row.entitlement
        film = row.film
        if type(ent) <> "roAssociativeArray" or type(film) <> "roAssociativeArray" then continue for
        if EmberStr(film.id) = "" or EmberStr(film.title) = "" then continue for

        state = EmberRentalState(ent, row.screening, now)

        resumeSeconds = 0
        if type(row.resume) = "roAssociativeArray" and row.resume.position_seconds <> invalid then
            resumeSeconds = Int(row.resume.position_seconds)
        end if
        duration = 0
        if film.duration_minutes <> invalid then duration = Int(film.duration_minutes)

        poster = EmberStr(film.thumbnail_url)
        if poster = "" then poster = EmberStr(film.banner_image_url)
        slug = EmberStr(film.slug)

        item = root.CreateChild("ContentNode")
        item.id = film.id
        item.title = film.title
        item.hdPosterUrl = poster
        item.description = state.label
        item.addFields({
            filmId: film.id
            slug: slug
            watchable: state.watchable
            upcoming: state.upcoming
            resumeSeconds: resumeSeconds
            durationMinutes: duration
        })
    end for
    return { ok: true, signedOut: false, error: "", content: root }
end function

' { label, watchable, upcoming }: time left, upcoming screening, or ended.
function EmberRentalState(ent as Object, screening as Dynamic, now as Integer) as Object
    starts = EmberParseTime(ent.starts_at)
    ends = EmberParseTime(ent.expires_at)
    isScreening = (EmberStr(ent.type) = "public_performance")

    if starts > now then
        label = "Starts soon"
        if isScreening and type(screening) = "roAssociativeArray" and EmberStr(screening.screening_date) <> "" then
            label = "Screening " + screening.screening_date
        end if
        return { label: label, watchable: false, upcoming: true }
    end if
    if EmberStr(ent.status) <> "active" or (ends > 0 and ends <= now) then
        return { label: "Expired", watchable: false, upcoming: false }
    end if
    if ends = 0 then return { label: "Ready to watch", watchable: true, upcoming: false }

    minutes = Int((ends - now) / 60)
    if minutes < 1 then minutes = 1
    if minutes >= 24 * 60 then
        label = "Expires in " + Int(minutes / (24 * 60)).ToStr() + "d"
    else if minutes >= 60 then
        label = "Expires in " + Int(minutes / 60).ToStr() + "h " + (minutes mod 60).ToStr() + "m"
    else
        label = "Expires in " + minutes.ToStr() + "m"
    end if
    return { label: label, watchable: true, upcoming: false }
end function

' ---- Playback and progress ----

' A fresh signed HLS URL for this Roku. Request one on every play.
' { ok, url, signedOut, error }
function EmberStartPlayback(filmId as String) as Object
    cfg = EmberConfig()
    resp = EmberAuthorized("POST", "v2/playback/" + filmId, { client: cfg.client, device_id: EmberDeviceId() })
    if resp.signedOut then return { ok: false, url: "", signedOut: true, error: "Please sign in again." }
    data = resp.data
    if resp.status = 200 and type(data) = "roAssociativeArray" and type(data.playback) = "roAssociativeArray" then
        if data.playback.url <> invalid then
            return { ok: true, url: data.playback.url, signedOut: false, error: "" }
        end if
    end if
    return { ok: false, url: "", signedOut: false, error: EmberErrorMessage(resp, "This film can't be played right now.") }
end function

' Resume position, shared across the viewer's devices. Failures are ignored:
' progress is a convenience and must never interrupt playback.
sub EmberReportProgress(filmId as String, seconds as Integer)
    if seconds < 0 then return
    cfg = EmberConfig()
    EmberAuthorized("POST", "v2/progress", {
        film_id: filmId
        device_id: EmberDeviceId()
        client: cfg.client
        position_seconds: seconds
    })
end sub
