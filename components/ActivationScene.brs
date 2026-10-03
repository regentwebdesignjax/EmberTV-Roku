' components/ActivationScene.brs

sub init()
    m.urlLabel    = m.top.findNode("urlLabel")
    m.codeLabel   = m.top.findNode("codeLabel")
    m.statusLabel = m.top.findNode("statusLabel")
    m.steps       = m.top.findNode("steps")
    m.errorLabel  = m.top.findNode("errorLabel")
    m.qrGroup     = m.top.findNode("qrGroup")
    m.qrPoster    = m.top.findNode("qrPoster")

    m.retryBtn   = m.top.findNode("retryBtn")
    m.retryFill  = m.top.findNode("retryFill")
    m.retryLabel = m.top.findNode("retryLabel")
    m.emailBtn   = m.top.findNode("emailBtn")
    m.emailFill  = m.top.findNode("emailFill")
    m.emailLabel = m.top.findNode("emailLabel")

    m.urlLabel.text = EmberWebsiteName() + "/activate"

    m.task = invalid
    m.hasError = false
    ' "retry" | "email"
    m.focused = "email"
    renderButtons()

    m.top.observeField("start", "onStart")
    m.top.observeField("stop", "onStop")
end sub

' Shown on screen, so no scheme. Matches EmberConfig().websiteDisplayName.
function EmberWebsiteName() as String
    if CreateObject("roAppInfo").GetValue("ember_env") = "staging" then return "staging--embertv.netlify.app"
    return "app.emberstreaming.com"
end function

sub onStart()
    if m.top.start <> true then return
    startTask()
    m.top.setFocus(true)
end sub

sub onStop()
    if m.top.stop <> true then return
    stopTask()
end sub

sub startTask()
    stopTask()
    m.hasError = false
    m.errorLabel.visible = false
    m.steps.visible = true
    m.qrGroup.visible = false
    m.codeLabel.text = ""
    m.statusLabel.text = "Getting your code..."
    m.focused = "email"
    renderButtons()

    m.task = CreateObject("roSGNode", "ActivationTask")
    m.task.observeField("code", "onCode")
    m.task.observeField("status", "onStatus")
    m.task.control = "RUN"
end sub

sub stopTask()
    if m.task = invalid then return
    m.task.unobserveField("code")
    m.task.unobserveField("status")
    m.task.cancel = true
    m.task = invalid
end sub

sub onCode()
    if m.task = invalid then return
    c = m.task.code
    if c = invalid or c.userCode = invalid then return
    m.codeLabel.text = c.userCode
    m.qrPoster.uri = c.qrUrl
    m.qrGroup.visible = true
    m.statusLabel.text = "Waiting for you to approve..."
end sub

sub onStatus()
    if m.task = invalid then return
    s = m.task.status
    if s = "approved" then
        stopTask()
        m.top.signedIn = true
    else if s = "error" then
        message = m.task.error
        stopTask()
        showError(message)
    end if
end sub

sub showError(message as String)
    m.hasError = true
    m.steps.visible = false
    m.qrGroup.visible = false
    if message = "" then message = "Something went wrong. Please try again in a moment."
    m.errorLabel.text = message
    m.errorLabel.visible = true
    m.focused = "retry"
    renderButtons()
end sub

sub renderButtons()
    m.retryBtn.visible = m.hasError
    if m.hasError then
        m.emailBtn.translation = [340, 0]
    else
        m.emailBtn.translation = [0, 0]
    end if
    styleButton(m.retryFill, m.retryLabel, m.focused = "retry")
    styleButton(m.emailFill, m.emailLabel, m.focused = "email")
end sub

sub styleButton(fill as Object, label as Object, focused as Boolean)
    if focused then
        fill.color = "0xEBEBEBFF"
        label.color = "0x121212FF"
    else
        fill.color = "0x2A2A2AFF"
        label.color = "0xAAAAAAFF"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" and m.hasError and m.focused = "email" then
        m.focused = "retry"
        renderButtons()
        return true
    else if key = "right" and m.hasError and m.focused = "retry" then
        m.focused = "email"
        renderButtons()
        return true
    else if key = "OK" then
        if m.focused = "retry" then
            startTask()
        else
            stopTask()
            m.top.emailRequested = true
        end if
        return true
    end if
    return false
end function
