' source/utils.brs

' ---- Network Helpers (Required by apiClient) ----

function httpPostJson(url as String, body as Object, headers as Object) as Object
    return _httpRequest("POST", url, body, headers)
end function

function httpGetJson(url as String, headers as Object) as Object
    return _httpRequest("GET", url, invalid, headers)
end function

function _httpRequest(method as String, url as String, body as Object, headers as Object) as Object
    xfer = CreateObject("roUrlTransfer")
    xfer.SetUrl(url)
    xfer.SetCertificatesFile("common:/certs/ca-bundle.crt")
    xfer.InitClientCertificates()
    xfer.RetainBodyOnError(true)

    ' Default headers
    xfer.AddHeader("Content-Type", "application/json")
    xfer.AddHeader("Accept", "application/json")

    ' Add custom headers
    if headers <> invalid
        for each key in headers
            xfer.AddHeader(key, headers[key])
        end for
    end if

    port = CreateObject("roMessagePort")
    xfer.SetPort(port)

    timeout = 10000 ' 10 seconds
    responseStr = ""
    httpStatus = -1
    success = false

    if method = "POST"
        ' Convert body AA to JSON string
        jsonBody = FormatJson(body)
        if xfer.AsyncPostFromString(jsonBody)
            msg = wait(timeout, port)
            if type(msg) = "roUrlEvent"
                httpStatus = msg.GetResponseCode()
                responseStr = msg.GetString()
                if httpStatus >= 200 and httpStatus < 300 then success = true
            end if
        end if
    else ' GET
        if xfer.AsyncGetToString()
            msg = wait(timeout, port)
            if type(msg) = "roUrlEvent"
                httpStatus = msg.GetResponseCode()
                responseStr = msg.GetString()
                if httpStatus >= 200 and httpStatus < 300 then success = true
            end if
        end if
    end if

    ' Parse Response
    data = invalid
    if responseStr <> ""
        data = ParseJson(responseStr)
    end if

    return {
        ok: success,
        httpstatus: httpStatus,
        data: data,
        error: ""
    }
end function

' ---- Resume helpers ----
function EmberResumeSection() as Object
    return CreateObject("roRegistrySection", "EmberResume")
end function

function EmberSaveResumeSeconds(filmId as String, seconds as Integer) as Void
    if filmId = invalid or filmId = "" then return
    if seconds = invalid or seconds < 0 then return
    sec = EmberResumeSection()
    sec.Write(filmId, seconds.ToStr())
    sec.Flush()
end function

function EmberLoadResumeSeconds(filmId as String) as Integer
    if filmId = invalid or filmId = "" then return 0
    sec = EmberResumeSection()
    v = sec.Read(filmId)
    if v = invalid or v = "" then return 0
    return Val(v)
end function

function EmberClearResume(filmId as String) as Void
    if filmId = invalid or filmId = "" then return
    sec = EmberResumeSection()
    sec.Delete(filmId)
    sec.Flush()
end function