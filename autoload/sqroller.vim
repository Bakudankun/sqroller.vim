vim9script


const STYLES = {
  light: ['╵', '│', '╷'],
  heavy: ['╹', '┃', '╻'],
  block: ['▀', '█', '▄'],
  left:  ['▘', '▌', '▖'],
  right: ['▝', '▐', '▗'],
  ascii: ["'", '|', ','],
}

var mousetarget = 0


export def Enable()
  g:sqroller_config.enabled = true
  Update()
enddef


export def Disable()
  g:sqroller_config.enabled = false
  Update()
enddef


export def WinClosed(winid: number)
  Close(winid)
enddef


export def WinScrolled()
  for key in keys(v:event)
    if key == 'all'
      continue
    endif
    Update(str2nr(key))
  endfor
enddef


def Create(winid: number): number
  if !!GetPopup(winid)
    return GetPopup(winid)
  endif

  const popup = popup_create('', {
    border: [0, 0, 0, 0],
    fixed: true,
    highlight: 'Sqroller',
    zindex: 5,
    filter: PopupFilter,
  })
  setwinvar(winid, 'sqroller', popup)
  setwinvar(popup, 'sqroller_basewin', winid)

  Update(winid)

  return popup
enddef


export def Update(winid: number = 0)
  if !winid
    for i in range(winnr('$'))
      Update(win_getid(i + 1))
    endfor
    return
  endif

  const enabled = !!getwinvar(winid, 'sqroller_enabled',
    !!g:sqroller_config.enabled &&
    g:sqroller_config.hide_for->index(getwinvar(winid, '&filetype')) == -1)

  if !enabled
    Close(winid)
    return
  endif

  var popup = GetPopup(winid)
  if !popup
    popup = Create(winid)
  endif

  const width = &ambiwidth == 'single' || g:sqroller_config.style =~ 'ascii\|right' ? 1 : 2

  if getwinvar(winid, '&foldcolumn') != width
    setwinvar(winid, '&foldcolumn', width)
  endif

  const info = getwininfo(winid)[0]
  popup_move(popup, {
    line: info.winrow + info.winbar,
    col: info.wincol,
    maxheight: info.height,
    minheight: info.height,
    maxwidth: width,
    minwidth: width,
  })

  const chars = STYLES[g:sqroller_config.style]

  const buflines = line('$', winid)
  const top = (info.topline - 1.0) / buflines
  const bot = 1.0 * info.botline / buflines

  if top == 0.0 && bot == 1.0
    if !!g:sqroller_config.hide_full_bars
      popup_settext(popup, '')
    else
      popup_settext(popup, repeat(chars[1], info.height))
    endif
    return
  endif

  const bitnum = info.height * 2
  var firstbit: number
  var lastbit: number
  if g:sqroller_config.algorithm == 'topbot'
    firstbit = top == 0.0 ? 0 : ((bitnum - 2) * top)->float2nr() + 1
    lastbit = ((bitnum - 2) * bot)->float2nr() + 1
  else
    const length = (bitnum * (bot - top) + 0.5)->float2nr() ?? 1
    firstbit = top == 0.0 ? 0
      : bot == 1.0 ? bitnum - length
      : ((bitnum - 1.5) * top)->float2nr() + 1
    lastbit = firstbit + length - 1
  endif
  final text = repeat([''], info.height)
  for i in range(text->len())
    if i * 2 == lastbit
      text[i] = chars[0]
    elseif i * 2 + 1 == firstbit
      text[i] = chars[2]
    elseif i * 2 >= firstbit && i * 2 + 1 <= lastbit
      text[i] = chars[1]
    endif
  endfor
  popup_settext(popup, text)
enddef


def Close(winid: number)
  const popup = GetPopup(winid)
  if !!popup
    popup_close(popup)
    win_execute(winid, 'set foldcolumn<')
  endif
enddef


export def Hide(winid: number)
  GetPopup(winid)->popup_hide()
enddef


export def Show(winid: number)
  GetPopup(winid)->popup_show()
enddef


def GetPopup(winid: number): number
  const popup = getwinvar(winid, 'sqroller', -1)
  return win_gettype(popup) == 'popup' ? popup : 0
enddef


export def KillZombies()
  for popup in popup_list()
    const winid = getwinvar(popup, 'sqroller_basewin', 0)
    if !winid
      continue
    endif
    if getwinvar(winid, 'sqroller', 0) != popup
      popup_close(popup)
    endif
  endfor
enddef


def PopupFilter(winid: number, key: string): bool
  if key == "\<LeftRelease>" && mousetarget == winid
    mousetarget = 0
    return true
  endif

  if key != "\<LeftMouse>" && key != "\<LeftDrag>"
    return false
  endif

  const mousepos = getmousepos()
  if mousepos.winid != winid && mousetarget != winid
    return false
  endif

  const winpos = popup_getpos(winid)
  const height = winpos.core_height
  if height <= 1
    return false
  endif

  const basewin = getwinvar(winid, 'sqroller_basewin', 0)
  if !basewin
    return true
  endif

  if key == "\<LeftMouse>"
    mousetarget = winid
    if !g:sqroller_config.keepjumps
      win_execute(basewin, ":normal! m'")
    endif
  endif

  const pos = mousepos.screenrow - winpos.line + 1
  const dest = line('$', basewin) * (pos - 1) / (height - 1) ?? 1

  win_execute(basewin, $':keepjumps normal! {dest}zz')
  if line('w$', basewin) == line('$', basewin)
    const curpos = getcurpos(basewin)
    win_execute(basewin, $':keepjumps normal! Gzb')
    win_execute(basewin, $'cursor({curpos[1 :]})')
  endif

  return true
enddef
