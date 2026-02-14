sub init()
    m.focusTimer = m.top.findNode("focusTimer")
    m.emailValue = m.top.findNode("emailValue")
    m.passValue  = m.top.findNode("passValue")
    m.btnBg      = m.top.findNode("btnBg")
    m.btnText    = m.top.findNode("btnText")
    m.errorLabel = m.top.findNode("errorLabel")

    ' Ring references
    m.emailTop    = m.top.findNode("emailRingTop")
    m.emailBottom = m.top.findNode("emailRingBottom")
    m.emailLeft   = m.top.findNode("emailRingLeft")
    m.emailRight  = m.top.findNode("emailRingRight")
    m.passTop    = m.top.findNode("passRingTop")
    m.passBottom = m.top.findNode("passRingBottom")
    m.passLeft   = m.top.findNode("passRingLeft")
    m.passRight  = m.top.findNode("passRingRight")

    m.loginTask = m.top.findNode("loginTask")
    if m.loginTask <> invalid then
        m.loginTask.observeField("status", "onLoginTaskStatus")
    end if

    m._email = ""
    m._pass  = ""
    m._kbd = invalid
    m._editing = ""
    m.selectedIndex = 0
    m.isLoading = false
    m.emailChecked = false ' Keeps track if we already asked Roku for email

    hideError()
    renderFields()
    renderSelection()

    m.top.observeField("visible", "onVisibleChanged")
    if m.focusTimer <> invalid then m.focusTimer.observeField("fire", "onFocusTimerFire")
    
    m.top.signalBeacon("AppDialogInitiate")
end sub

sub onVisibleChanged()
    if m.top.visible <> true then return
    
    resetLoading()
    hideError()

    if m.focusTimer <> invalid then
        m.focusTimer.control = "stop"
        m.focusTimer.control = "start"
    else
        m.top.setFocus(true)
    end if
end sub

sub onFocusTimerFire()
    m.top.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if press = false then return false
    if m._kbd <> invalid then return false
    
    if m.isLoading = true then return true

    if key = "down" then
        if m.selectedIndex < 2 then m.selectedIndex = m.selectedIndex + 1
        renderSelection()
        return true
    end if

    if key = "up" then
        if m.selectedIndex > 0 then m.selectedIndex = m.selectedIndex - 1
        renderSelection()
        return true
    end if

    if key = "OK" then
        if m.selectedIndex = 0 then
            ' ✅ NEW LOGIC: Ask Roku for email first!
            if m.emailChecked = false
                triggerRokuEmailCheck()
            else
                openKeyboard("email")
            end if
            return true
        else if m.selectedIndex = 1 then
            openKeyboard("pass")
            return true
        else
            attemptLogin()
            return true
        end if
    end if

    return false
end function

' ✅ NEW: Runs when user clicks Email field
sub triggerRokuEmailCheck()
    m.emailChecked = true ' Mark done so we don't ask twice
    m.emailTask = CreateObject("roSGNode", "GetEmailTask")
    if m.emailTask <> invalid
        m.emailTask.observeField("email", "onEmailLoaded")
        m.emailTask.control = "RUN"
    else
        openKeyboard("email")
    end if
end sub

sub onEmailLoaded()
    ' If Roku gave us an email, fill it. If not, open keyboard.
    if m.emailTask.email <> invalid and m.emailTask.email <> "" then
        print "Found Roku Email: "; m.emailTask.email
        m._email = m.emailTask.email
        renderFields() 
    else
        openKeyboard("email")
    end if
end sub

sub renderSelection()
    setEmailOutline(m.selectedIndex = 0)
    setPassOutline(m.selectedIndex = 1)
    if m.btnBg <> invalid then
        if m.selectedIndex = 2 then
            m.btnBg.opacity = 1.0
        else
            m.btnBg.opacity = 0.92
        end if
    end if
end sub

sub setEmailOutline(v as Boolean)
    if m.emailTop <> invalid then m.emailTop.visible = v
    if m.emailBottom <> invalid then m.emailBottom.visible = v
    if m.emailLeft <> invalid then m.emailLeft.visible = v
    if m.emailRight <> invalid then m.emailRight.visible = v
end sub

sub setPassOutline(v as Boolean)
    if m.passTop <> invalid then m.passTop.visible = v
    if m.passBottom <> invalid then m.passBottom.visible = v
    if m.passLeft <> invalid then m.passLeft.visible = v
    if m.passRight <> invalid then m.passRight.visible = v
end sub

sub openKeyboard(which as String)
    m._editing = which
    kbd = CreateObject("roSGNode", "StandardKeyboardDialog")
    if kbd = invalid then return

    if which = "email" then
        kbd.title = "Email"
        kbd.text = m._email
    else
        kbd.title = "Password"
        kbd.text = m._pass
        if kbd.hasField("secure") then kbd.secure = true 
    end if

    kbd.buttons = ["Done", "Cancel"]
    kbd.observeField("buttonSelected", "onKbdButton")
    kbd.observeField("wasClosed", "onKbdClosed")

    scene = m.top.getScene()
    if scene <> invalid then
        scene.dialog = kbd
        m._kbd = kbd
    end if
end sub

sub onKbdButton()
    if m._kbd = invalid then return
    idx = m._kbd.buttonSelected
    if idx = 0 then
        t = m._kbd.text
        if t = invalid then t = ""
        if m._editing = "email" then
            m._email = t.trim()
            renderFields()
            closeKeyboard()
            m.selectedIndex = 1
            renderSelection()
            return
        else if m._editing = "pass" then
            m._pass = t
            renderFields()
            closeKeyboard()
            m.selectedIndex = 2
            renderSelection()
            return
        end if
    end if
    closeKeyboard()
end sub

sub onKbdClosed()
    closeKeyboard()
end sub

sub closeKeyboard()
    scene = m.top.getScene()
    if scene <> invalid then scene.dialog = invalid
    m._kbd = invalid
    m._editing = ""
end sub

sub renderFields()
    if m.emailValue <> invalid then
        if m._email <> "" then m.emailValue.text = m._email else m.emailValue.text = "you@example.com"
    end if
    if m.passValue <> invalid then
        if m._pass <> "" then m.passValue.text = "••••••••" else m.passValue.text = "••••••••"
    end if
end sub

sub attemptLogin()
    hideError()
    if m._email = "" then
        showError("Please enter your email.")
        m.selectedIndex = 0
        renderSelection()
        return
    end if
    if m._pass = "" then
        showError("Please enter your password.")
        m.selectedIndex = 1
        renderSelection()
        return
    end if

    m.isLoading = true
    if m.btnText <> invalid then m.btnText.text = "Signing in…"
    if m.btnBg <> invalid then m.btnBg.opacity = 0.5

    if m.loginTask <> invalid then
        m.loginTask.email = m._email
        m.loginTask.password = m._pass
        m.loginTask.control = "run"
    end if
end sub

sub onLoginTaskStatus()
    if m.loginTask = invalid then return
    s = m.loginTask.status
    if s = "success" then
        token = m.loginTask.token
        if token <> invalid and token <> "" then
            m.top.authToken = token
            m.top.loginSuccess = true
            m.top.signalBeacon("AppDialogComplete")
            return
        end if
        showError("Missing token.")
        resetLoading()
        return
    end if
    if s = "error" then
        err = m.loginTask.error
        if err = invalid or err = "" then err = "Unable to sign in."
        showError(err)
        resetLoading()
        return
    end if
end sub

sub resetLoading()
    m.isLoading = false
    if m.btnText <> invalid then m.btnText.text = "Sign In"
    if m.btnBg <> invalid then m.btnBg.opacity = 0.92
end sub

sub showError(msg as String)
    if m.errorLabel = invalid then return
    m.errorLabel.text = msg
    m.errorLabel.visible = true
end sub

sub hideError()
    if m.errorLabel = invalid then return
    m.errorLabel.visible = false
    m.errorLabel.text = ""
end sub