' source/apiClient.brs

function EmberAPIClient() as Object
    client = {
        _baseUrl: "https://embervod.base44.app"
        _appPath: "/api/apps/691721b89e14bc8b401725d6/functions"
        _fnLogin: "authLogin"
        _fnMyRentals: "apiMyRentals"
    }

    ' FIX: Use 'm' instead of 'client' to access properties inside the function
    client.login = function(email as String, password as String) as Object
        url = m._baseUrl + m._appPath + "/" + m._fnLogin
        headers = {
            "Accept": "application/json"
            "Content-Type": "application/json"
        }
        body = { email: email, password: password }

        ' Requires httpPostJson from source/utils.brs
        resp = httpPostJson(url, body, headers)
        
        if resp = invalid or resp.ok <> true then
            err = "Unable to sign in."
            if resp <> invalid and resp.data <> invalid and resp.data.error <> invalid then err = resp.data.error
            if resp <> invalid and resp.error <> invalid then err = resp.error
            
            httpStatus = 0
            if resp <> invalid then httpStatus = resp.httpstatus
            
            return { ok: false, error: err, httpstatus: httpStatus }
        end if

        token = ""
        user = invalid
        if resp.data <> invalid then
            if resp.data.token <> invalid then token = resp.data.token
            if resp.data.user <> invalid then user = resp.data.user
        end if

        if token = "" then return { ok: false, error: "Missing token in response.", httpstatus: resp.httpstatus }

        return { ok: true, token: token, user: user, httpstatus: resp.httpstatus }
    end function

    ' FIX: Use 'm' here as well
    client.fetchMyRentals = function(token as String) as Object
        url = m._baseUrl + m._appPath + "/" + m._fnMyRentals
        headers = {
            "Accept": "application/json"
            "Content-Type": "application/json"
            "Authorization": "Bearer " + token
        }

        ' Requires httpGetJson from source/utils.brs
        resp = httpGetJson(url, headers)
        
        if resp = invalid or resp.ok <> true then
            err = "Unable to load rentals."
            if resp <> invalid and resp.data <> invalid and resp.data.error <> invalid then err = resp.data.error
            if resp <> invalid and resp.error <> invalid then err = resp.error
            
            httpStatus = 0
            if resp <> invalid then httpStatus = resp.httpstatus

            return { ok: false, error: err, httpstatus: httpStatus }
        end if

        rentals = []
        if resp.data <> invalid then
            ' Base44 often returns { data: [...] }
            if resp.data.data <> invalid then 
                rentals = resp.data.data
            else if type(resp.data) = "roArray" then 
                rentals = resp.data
            end if
        end if

        return { ok: true, rentals: rentals, httpstatus: resp.httpstatus }
    end function

    return client
end function