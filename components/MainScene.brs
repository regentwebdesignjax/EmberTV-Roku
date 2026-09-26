' components/MainScene.brs
'
' Moves between the screens: activation-code sign-in (or email sign-in),
' My Rentals, and the player. Also handles deep links, Instant Resume and
' low-memory warnings forwarded from main.brs.

' Offer "Resume" once the viewer is at least this far in.
function MinResumeSeconds() as Integer
    return 60
end function

sub init()
    m._launchSignaled = false
    m._dialogOpen = false
    m._pendingDeepLink = ""
    m._pendingRental = invalid

    m.activationScene = m.top.findNode("activationScene")
    m.loginScene      = m.top.findNode("loginScene")
    m.rentalsScene    = m.top.findNode("rentalsScene")
    m.playerScene     = m.top.findNode("playerScene")
    m.signOutTask     = m.top.findNode("signOutTask")

    m.activationScene.observeField("signedIn", "onSignedIn")
    m.activationScene.observeField("emailRequested", "onEmailRequested")
    m.loginScene.observeField("signedIn", "onSignedIn")
    m.loginScene.observeField("backRequested", "onLoginBack")
    m.rentalsScene.observeField("selectedRental", "onSelectedRental")
    m.rentalsScene.observeField("logoutRequested", "onLogoutRequested")
    m.rentalsScene.observeField("signedOut", "onSessionEnded")
    m.rentalsScene.observeField("library", "onLibraryLoaded")
    m.playerScene.observeField("backRequested", "onPlayerBackRequested")
    m.playerScene.observeField("signedOut", "onSessionEnded")
    m.signOutTask.observeField("response", "onSignOutDone")

    EmberClearLegacyState()

    if EmberHasSession() then
        showRentals()
    else
        ' Sign-in at launch: Roku excludes it from launch timing (cert 3.2).
        m.top.signalBeacon("AppDialogInitiate")
        m._dialogOpen = true
        showActivation()
    end if

    signalLaunchComplete()
end sub

' AppLaunchComplete must be signaled exactly once per launch.
sub signalLaunchComplete()
    if m._launchSignaled = true then return
    m._launchSignaled = true
    m.top.signalBeacon("AppLaunchComplete")
end sub

sub showOnly(which as String)
    m.activationScene.visible = (which = "activation")
    m.loginScene.visible = (which = "login")
    m.rentalsScene.visible = (which = "rentals")
    m.playerScene.visible = (which = "player")

    if which = "activation" then m.activationScene.setFocus(true)
    if which = "login" then m.loginScene.setFocus(true)
    if which = "rentals" then m.rentalsScene.setFocus(true)
    if which = "player" then m.playerScene.setFocus(true)
end sub

' ---- Sign-in ----

sub showActivation()
    showOnly("activation")
    m.activationScene.start = true
end sub

sub onEmailRequested()
    if m.activationScene.emailRequested <> true then return
    showOnly("login")
end sub

sub onLoginBack()
    if m.loginScene.backRequested <> true then return
    showActivation()
end sub

sub onSignedIn()
    m.activationScene.stop = true
    if m._dialogOpen then
        m._dialogOpen = false
        m.top.signalBeacon("AppDialogComplete")
    end if
    showRentals()
end sub

sub showRentals()
    showOnly("rentals")
    m.rentalsScene.reload = true
end sub

' The server revoked the session (or it expired for good): sign in again.
sub onSessionEnded()
    closeDialog()
    m.playerScene.content = invalid
    showActivation()
end sub

sub onLogoutRequested()
    if m.rentalsScene.logoutRequested <> true then return
    m.signOutTask.request = { action: "signOut" }
    m.signOutTask.control = "RUN"
end sub

sub onSignOutDone()
    showActivation()
end sub

' ---- Library and playback ----

sub onLibraryLoaded()
    if m._pendingDeepLink = "" then return
    id = m._pendingDeepLink
    m._pendingDeepLink = ""
    playFromLibrary(id)
end sub

sub onSelectedRental()
    item = m.rentalsScene.selectedRental
    if item = invalid then return
    openRental(item)
end sub

' Plays a rental, asking first whether to resume when there is a resume point.
' A deep link ([direct]) plays straight away, from the resume point if any:
' Roku expects deep links to go directly to playback, with no prompt.
sub openRental(item as Object, direct = false as Boolean)
    if item.hasField("watchable") and item.watchable <> true then
        message = "This rental has ended."
        if item.hasField("upcoming") and item.upcoming = true then message = "This screening isn't available to play yet."
        showMessageDialog(item.title, message)
        return
    end if

    resume = 0
    if item.hasField("resumeSeconds") and item.resumeSeconds <> invalid then resume = item.resumeSeconds
    canResume = resume >= MinResumeSeconds() and not nearEnd(item, resume)
    if direct then
        if canResume then
            playRental(item, resume)
        else
            playRental(item, 0)
        end if
        return
    end if
    if canResume then
        m._pendingRental = item
        dlg = CreateObject("roSGNode", "StandardMessageDialog")
        dlg.title = item.title
        dlg.message = ["Resume from " + EmberFormatClock(resume) + ", or start from the beginning?"]
        dlg.buttons = ["Resume", "Start Over"]
        dlg.observeField("buttonSelected", "onResumeChoice")
        dlg.observeField("wasClosed", "onDialogClosed")
        m.top.dialog = dlg
        return
    end if
    playRental(item, 0)
end sub

' Within the last minute: the film was essentially finished.
function nearEnd(item as Object, seconds as Integer) as Boolean
    if not item.hasField("durationMinutes") then return false
    minutes = item.durationMinutes
    if minutes = invalid or minutes <= 0 then return false
    return seconds > minutes * 60 - 60
end function

sub onResumeChoice()
    dlg = m.top.dialog
    item = m._pendingRental
    m._pendingRental = invalid
    if dlg = invalid or item = invalid then return
    choice = dlg.buttonSelected
    closeDialog()
    if choice = 0 then
        playRental(item, item.resumeSeconds)
    else
        playRental(item, 0)
    end if
end sub

sub showMessageDialog(title as String, message as String)
    dlg = CreateObject("roSGNode", "StandardMessageDialog")
    dlg.title = title
    dlg.message = [message]
    dlg.buttons = ["OK"]
    dlg.observeField("buttonSelected", "onDialogClosed")
    dlg.observeField("wasClosed", "onDialogClosed")
    m.top.dialog = dlg
end sub

sub onDialogClosed()
    m._pendingRental = invalid
    closeDialog()
end sub

sub closeDialog()
    if m.top.dialog <> invalid then m.top.dialog.close = true
    m.top.dialog = invalid
end sub

sub playRental(item as Object, startAt as Integer)
    c = CreateObject("roSGNode", "ContentNode")
    c.title = item.title
    c.addFields({ filmId: item.filmId, startAt: startAt })
    m.playerScene.backRequested = false
    showOnly("player")
    m.playerScene.content = c
end sub

sub onPlayerBackRequested()
    if m.playerScene.backRequested <> true then return
    m.playerScene.backRequested = false
    ' Reload so time left and resume points are current.
    showRentals()
end sub

' ---- Deep links ----

' params: { id, type } from main.brs. The id is a film's id or slug; the film
' plays if it is in this account's library and watchable. Signed out, it
' plays after sign-in, exactly as a customer would see it.
sub handleDeepLink(params as Object)
    if params = invalid then return
    id = ""
    if params.id <> invalid then
        id = params.id.ToStr()
    else if params.contentId <> invalid then
        id = params.contentId.ToStr()
    end if
    if id = "" then return
    print "MainScene: deep link "; id

    closeDialog()
    m._pendingDeepLink = id
    if EmberHasSession() then
        ' Stop anything playing and look the film up in a fresh library.
        m.playerScene.content = invalid
        showRentals()
    end if
end sub

sub playFromLibrary(id as String)
    library = m.rentalsScene.library
    if library = invalid then return
    for i = 0 to library.getChildCount() - 1
        item = library.getChild(i)
        if item.filmId = id or (item.hasField("slug") and item.slug = id) then
            openRental(item, true)
            return
        end if
    end for
    ' Not rented on this account: stay on My Rentals.
end sub

function handleInstantResume(args as Dynamic) as Void
    print "MainScene: Instant Resume received"
    if m.playerScene.visible then
        m.playerScene.setFocus(true)
    else if m.rentalsScene.visible then
        m.rentalsScene.setFocus(true)
    else if m.loginScene.visible then
        m.loginScene.setFocus(true)
    else
        m.activationScene.setFocus(true)
    end if
    signalLaunchComplete()
end function

' Release what we can when the OS warns we are near the per-app memory limit.
function handleLowMemory(params as Dynamic) as Void
    if params <> invalid and params.percent <> invalid
        print "MainScene: low memory at "; params.percent; "% of app limit"
    else if params <> invalid and params.level <> invalid
        print "MainScene: low memory, system level="; params.level
    end if

    ' While the player is up the rentals grid is off-screen, so its posters are
    ' the cheapest thing to give back. RentalsScene refetches when shown again.
    if m.playerScene.visible = true then
        m.rentalsScene.callFunc("releaseCachedContent", {})
    end if
end function
