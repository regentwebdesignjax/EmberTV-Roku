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

        ' DEBUG: Print the film object
        print "RENTALS DUMP: " + FormatJson(film)

        item = CreateObject("roSGNode", "ContentNode")

        ' 1. Title
        title = ""
        if film.title <> invalid then title = film.title
        item.Title = title

        ' 2. Poster
        ' Use Raw URL. The XML change (scaleToFit) handles the display.
        poster = ""
        if film.poster_url <> invalid then poster = film.poster_url
        if poster = "" and film.poster <> invalid then poster = film.poster
        item.HDPosterUrl = poster

        ' 3. Stream URL - Priority Selection
        ' We use the HTTPS URL directly.
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

        ' 4. Robust Format Detection
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

        ' 5. Stream Configuration - The BunnyCDN Fix
        ' We enable 'useInsecureHTTPS' to bypass the strict SSL handshake that fails on Bunny.
        ' We enable 'nativeHlsParsingEnabled' to use the modern OS parser.
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
        
        ' Reset bitrates to let Roku Adaptive work automatically
        item.StreamBitrates = [0] 

        print "FINAL VIDEO CONFIG: URL=" + streamUrl + " | FMT=" + fmt

        ' 6. Meta
        if film.year <> invalid then item.year = film.year
        if film.genre <> invalid then item.genre = film.genre
        if film.id <> invalid then item.id = film.id

        root.AppendChild(item)
    end for

    m.top.content = root
    m.top.status = "loaded"
end sub