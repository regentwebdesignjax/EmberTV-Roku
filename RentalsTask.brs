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

        ' DEBUG: Print the film object so we can find the URL field name
        print "RENTALS DUMP: " + FormatJson(film)

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

        ' 3. Stream URL (Check multiple possible keys)
        streamUrl = ""
        if film.stream_url <> invalid then streamUrl = film.stream_url
        if streamUrl = "" and film.hls_url <> invalid then streamUrl = film.hls_url
        if streamUrl = "" and film.video_url <> invalid then streamUrl = film.video_url
        if streamUrl = "" and film.url <> invalid then streamUrl = film.url
        
        item.url = streamUrl

        item.streamFormat = "hls"

        ' 4. Meta
        if film.year <> invalid then item.year = film.year
        if film.genre <> invalid then item.genre = film.genre
        if film.id <> invalid then item.id = film.id

        root.AppendChild(item)
    end for

    m.top.content = root
    m.top.status = "loaded"
end sub