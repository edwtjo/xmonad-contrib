-----------------------------------------------------------------------------
-- |
-- Module       : XMonad.Hooks.FadeInactive
-- Copyright    : (c) 2008 Justin Bogner <mail@justinbogner.com>
-- License      : BSD
--
-- Maintainer   : Justin Bogner <mail@justinbogner.com>
-- Stability    : unstable
-- Portability  : unportable
--
-- Makes XMonad set the _NET_WM_WINDOW_OPACITY atom for inactive windows,
-- which causes those windows to become slightly translucent if something
-- like xcompmgr is running
-----------------------------------------------------------------------------
module XMonad.Hooks.FadeInactive (
    -- * Usage
    -- $usage
    setOpacity,
    isUnfocused,
    fadeIn,
    fadeOut,
    fadeIf,
    fadeInactiveLogHook,
    fadeOutLogHook
    ) where

import XMonad
import qualified XMonad.StackSet as W
import Control.Monad

-- $usage
-- You can use this module with the following in your @~\/.xmonad\/xmonad.hs@:
--
-- > import XMonad
-- > import XMonad.Hooks.FadeInactive
-- >
-- > myLogHook :: X ()
-- > myLogHook = fadeInactiveLogHook fadeAmount
-- >     where fadeAmount = 0.8
-- >
-- > main = xmonad defaultConfig { logHook = myLogHook }
--
-- fadeAmount can be any rational between 0 and 1.
-- you will need to have xcompmgr <http://freedesktop.org/wiki/Software/xapps>
-- or something similar for this to do anything
--
-- For more detailed instructions on editing the layoutHook see:
--
-- "XMonad.Doc.Extending#The_log_hook_and_external_status_bars"
--
-- For more detailed instructions on editing the layoutHook see:
--
-- "XMonad.Doc.Extending#Editing_the_layout_hook"

-- | Converts a percentage to the format required for _NET_WM_WINDOW_OPACITY
rationalToOpacity :: Integral a => Rational -> a
rationalToOpacity perc
    | perc < 0 || perc > 1 = 0xffffffff -- invalid input, default to opaque
    | otherwise = round $ perc * 0xffffffff

-- | sets the opacity of a window
setOpacity :: Window -> Rational -> X ()
setOpacity w t = withDisplay $ \dpy -> do
    a <- getAtom "_NET_WM_WINDOW_OPACITY"
    c <- getAtom "CARDINAL"
    io $ changeProperty32 dpy w a c propModeReplace [rationalToOpacity t]

-- | fades a window out by setting the opacity
fadeOut :: Rational -> Window -> X ()
fadeOut = flip setOpacity

-- | makes a window completely opaque
fadeIn :: Window -> X ()
fadeIn = fadeOut 1

-- | Fades a window by the specified amount if it satisfies the first query, otherwise
-- makes it opaque.
fadeIf :: Query Bool -> Rational -> Query Rational
fadeIf qry amt = qry >>= \b -> return $ if b then amt else 1

-- | sets the opacity of inactive windows to the specified amount
fadeInactiveLogHook :: Rational -> X ()
fadeInactiveLogHook = fadeOutLogHook . fadeIf isUnfocused

-- | returns True if the window doesn't have the focus.
isUnfocused :: Query Bool
isUnfocused = ask >>= \w -> liftX . gets $ maybe False (w /=) . W.peek . windowset

-- | fades out every window by the amount returned by the query.
fadeOutLogHook :: Query Rational -> X ()
fadeOutLogHook qry = withWindowSet $ \s -> do
    let visibleWins = (W.integrate' . W.stack . W.workspace . W.current $ s) ++
                      concatMap (W.integrate' . W.stack . W.workspace) (W.visible s)
    forM_ visibleWins $ liftM2 (=<<) setOpacity (runQuery qry)
