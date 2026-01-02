sub init()
    m.top.functionName = "getEmail"
end sub

sub getEmail()
    ' Create the store object to fetch user info
    store = CreateObject("roChannelStore")
    
    ' This call satisfies Roku Requirement RP 4.1
    data = store.getUserData() 
    
    if data <> invalid and data.email <> invalid
        m.top.email = data.email
    else
        m.top.email = ""
    end if
end sub