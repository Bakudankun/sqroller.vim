vim9script

import autoload "sqroller.vim"


const sqroller_default_config = {
  algorithm: 'keeplen',
  enabled: true,
  hide_for: [],
  hide_full_bars: false,
  keepjumps: false,
  style: 'heavy',
}

if !exists('g:sqroller_config')
  g:sqroller_config = {}
endif
g:sqroller_config->extend(sqroller_default_config, 'keep')


command SqrollerEnable sqroller.Enable()
command SqrollerDisable sqroller.Disable()


augroup sqroller
  autocmd!
  autocmd WinClosed * sqroller.WinClosed(expand("<amatch>")->str2nr())
  autocmd WinScrolled * sqroller.WinScrolled()
  autocmd TabEnter,VimResized * sqroller.Update()
  autocmd OptionSet foldcolumn sqroller.Update(win_getid())
  autocmd BufWinEnter,TextChanged,TextChangedI * sqroller.Update(win_getid())
  autocmd ModeChanged *:t* sqroller.Hide(win_getid())
  autocmd ModeChanged t*:* sqroller.Show(win_getid())
  autocmd CursorHold,CursorHoldI * sqroller.KillZombies()
augroup END


highlight default link Sqroller FoldColumn


sqroller.Update()
