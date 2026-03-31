' components/RentalsTask.brs

sub init()
    m.top.functionName = "execute"
end sub

sub execute()
    m.top.status = "loading"
    m.top.error = ""
    m.top.content = invalid

    token = m.top.authToken
    if token = invalid or token = "" then
        m.top.status = "error"
        m.top.error = "Not authenticated."
        return
    end if

    api = EmberAPIClient()
    print "RENTALS TASK: calling fetchMyRentals()"
    resp = api.fetchMyRentals(token)

    if resp = invalid or resp.ok <> true then
        err = "Unable to load rentals."
        if resp <> invalid and resp.error <> invalid then err = resp.error
        m.top.status = "error"
        m.top.error = err
        return
    end if

    rentals = resp.rentals
    if rentals = invalid then rentals = []

    root = CreateObject("roSGNode", "ContentNode")
    root.Title = "My Rentals"

    for each r in rentals
        if r = invalid then continue for

        ' normalize film object
        film = invalid
        if r.film <> invalid then film = r.film else film = r
        if film = invalid then continue for

        item = CreateObject("roSGNode", "ContentNode")

        ' 1. Title
        title = ""
        if film.title <> invalid then title = film.title
        item.Title = title

        ' 2. Poster
        poster = ""
        if film.poster_url <> invalid then poster = film.poster_url
        if poster = "" and film.poster <> invalid then poster = film.poster
        item.HDPosterUrl = poster

        ' 3. Stream URL
        streamUrl = ""
        if film.hls_url <> invalid and film.hls_url <> "" then
            streamUrl = film.hls_url
        else if film.stream_url <> invalid and film.stream_url <> "" then
            streamUrl = film.stream_url
        else if film.video_url <> invalid and film.video_url <> "" then
            streamUrl = film.video_url
        else if film.url <> invalid and film.url <> "" then
            streamUrl = film.url
        end if
        
        item.url = streamUrl

        ' 4. Format Detection
        u = LCase(streamUrl)
        fmt = "hls" ' Default
        if Instr(1, u, ".mp4") > 0 or Instr(1, u, ".mkv") > 0 then
            fmt = "mp4"
        else if Instr(1, u, ".m3u8") > 0 then
            fmt = "hls"
        else if Instr(1, u, ".mpd") > 0 then
            fmt = "dash"
        end if
        item.streamFormat = fmt

        ' 5. Stream Configuration
        item.addField("stream", "assocarray", false)
        item.setField("stream", {
            url: streamUrl,
            contentid: film.id,
            quality: false,
            stickyHttpRedirects: true,
            useInsecureHTTPS: true,
            nativeHlsParsingEnabled: true,
            streamFormat: fmt
        })
        
        item.StreamBitrates = [0] 

        ' 6. Meta
        if film.year <> invalid then item.year = film.year
        if film.genre <> invalid then item.genre = film.genre
        if film.id <> invalid then item.id = film.id

        ' 7. RENTAL EXPIRATION MATH
        expirationText = "Expires in 48h" 
        
        if r.expires_in <> invalid then
            expirationText = "Expires in " + r.expires_in.ToStr()
        else if r.time_left <> invalid then
            expirationText = r.time_left.ToStr() + " remaining"
        else if r.expires_at <> invalid then
            ' Call our new helper function below to calculate the time left!
            expirationText = calculateTimeRemaining(r.expires_at)
        end if
        
        item.description = expirationText

        root.AppendChild(item)
    end for

    m.top.content = root
    m.top.status = "loaded"
end sub

' ---- NEW HELPER FUNCTION ----
' Takes a timestamp, compares it to current time, and formats it beautifully.
function calculateTimeRemaining(expiresAt as Dynamic) as String
    now = CreateObject("roDateTime")
    nowSeconds = now.AsSeconds()

    expTime = CreateObject("roDateTime")
    
    ' Handle if the API sends an ISO string (e.g., "2026-03-31T12:00:00Z")
    if type(expiresAt) = "roString" or type(expiresAt) = "String" then
        expTime.FromISO8601String(expiresAt)
    ' Handle if the API sends a raw unix timestamp number
    else if type(expiresAt) = "roInt" or type(expiresAt) = "roInteger" or type(expiresAt) = "roFloat" or type(expiresAt) = "roDouble" then
        expTime.FromSeconds(Int(expiresAt))
    else
        return "Expires soon"
    end if

    expSeconds = expTime.AsSeconds()
    diff = expSeconds - nowSeconds

    if diff <= 0 then return "Expired"

    ' Calculate Hours and Minutes
    hours = Int(diff / 3600)
    mins = Int((diff MOD 3600) / 60)

    ' Format the output cleanly
    if hours > 48 then
        days = Int(hours / 24)
        return "Expires in " + days.ToStr() + " days"
    else if hours > 0 then
        ' E.g., "Expires in 47h 30m"
        return "Expires in " + hours.ToStr() + "h " + mins.ToStr() + "m"
    else
        ' Under an hour
        return "Expires in " + mins.ToStr() + "m"
    end if
end function