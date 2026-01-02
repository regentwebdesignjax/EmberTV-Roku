sub init()
  m.poster = m.top.findNode("poster")
  m.caption = m.top.findNode("caption")
  m.meta = m.top.findNode("meta")
  m.focusBorder = m.top.findNode("focusBorder")

  if m.top.hasField("focused") then
    m.top.observeField("focused", "onFocusedChanged")
  end if
end sub

' IMPORTANT: this must match PosterItem.xml onChange="onItemContentChanged"
sub onItemContentChanged()
  c = m.top.itemContent
  if c = invalid then return

  ' Poster url
  url = invalid
  if c.Lookup("hdPosterUrl") <> invalid and c.hdPosterUrl <> "" then
    url = c.hdPosterUrl
  else if c.Lookup("url") <> invalid and c.url <> "" then
    url = c.url
  end if

  if url <> invalid then
    m.poster.uri = url
  else
    m.poster.uri = ""
  end if

  ' Title
  if c.Lookup("title") <> invalid then
    m.caption.text = c.title
  else
    m.caption.text = ""
  end if

  ' Optional meta (safe if missing)
  year = ""
  genre = ""

  if c.Lookup("year") <> invalid and c.year <> invalid then year = c.year.ToStr()
  if c.Lookup("genre") <> invalid and c.genre <> invalid then genre = c.genre

  if year <> "" and genre <> "" then
    m.meta.text = year + " • " + genre
  else if year <> "" then
    m.meta.text = year
  else if genre <> "" then
    m.meta.text = genre
  else
    m.meta.text = ""
  end if
end sub

sub onFocusedChanged()
  if m.top.focused = true then
    m.focusBorder.opacity = 0.35
  else
    m.focusBorder.opacity = 0.0
  end if
end sub
