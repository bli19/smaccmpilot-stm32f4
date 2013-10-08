{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE Rank2Types #-}

{-# OPTIONS_GHC -fno-warn-orphans #-}

-- Hx streaming library.

module Ivory.HXStream where

import Ivory.Language
import Ivory.Stdlib
import Ivory.HXStream.Types

--------------------------------------------------------------------------------

type Hx  = Struct "hxstream_state"
type Tag = Uint8

[ivory|

struct hxstream_state
  { offset  :: Stored Sint32
  ; fstate  :: Stored HXState
  ; ftag    :: Stored Uint8 -- Frame tag
  }

|]

--------------------------------------------------------------------------------

emptyStreamState :: Ref s Hx -> Ivory eff ()
emptyStreamState state = do
  store (state ~> offset) 0
  store (state ~> fstate)  hxstate_progress
  -- Don't care about the frame tag---shouldn't be read unless there's a new
  -- frame.

initStreamState :: Init (Struct "hxstream_state")
initStreamState = istruct [ fstate .= ival hxstate_progress, offset .= ival 0 ]

--------------------------------------------------------------------------------
-- State-setting helpers

setState :: Ref s Hx -> HXState -> Ivory eff ()
setState state = store (state ~> fstate)

setTag :: Ref s Hx -> Tag -> Ivory eff ()
setTag state = store (state ~> ftag)

-- Increment the offset by one.
tickOffset :: Ref s Hx -> Ivory eff ()
tickOffset state = do
  off <- state ~>* offset
  store (state ~> offset) (off+1)

--------------------------------------------------------------------------------
-- Hxstream bytes

fbo :: Uint8
fbo  = 0x7e

ceo :: Uint8
ceo  = 0x7c

--------------------------------------------------------------------------------

escape :: Uint8 -> Uint8
escape = (.^) 0x20 -- XOR with 0x20

--------------------------------------------------------------------------------

-- | Decode a byte, given an hxstream state.  Returns a byte.  When the function
-- returns, if the hxstate makes the following transitions, we have the
-- following bytes returned:
--
-- hxstate_tag      --> hxstate_progress : tag byte
-- hxstate_progress --> hxstate_progress : frame byte
-- hxstate_esc      --> hxstate_progress : escaped frame byte
--
-- If we have
--
-- hxstate_progress --> hxstate_tag
--
-- A frame just ended.
decodeSM :: Def ('[ Ref s Hx, Uint8 ] :-> Uint8)
decodeSM = proc "decodeSM" $ \state b -> body $ do
  st <- state ~>* fstate
  byteRef <- local (ival 0)
  cond_
    [   -- If you see fbo, we're starting a new frame.
        -- byte.
        b ==? fbo
    ==> emptyStreamState state >> setState state hxstate_tag
        -- Get the tag in the tag state and get ready to process the rest.
    ,   st ==? hxstate_tag
    ==> setTag state b >> setState state hxstate_progress
        -- Progress
    ,   st ==? hxstate_progress
    ==> progress state b byteRef
        -- Handle escaped bytes.
    ,   st ==? hxstate_esc
    ==> do setState state hxstate_progress
           tickOffset state
           store byteRef (escape b)
        -- The impossible happened.
    ,   true
    ==> return ()
    ]
  ret =<< deref byteRef
  where
  progress state b byteRef =
    cond_ [ b ==? ceo ==> setState state hxstate_esc
          , true      ==> tickOffset state >> store byteRef b
          ]

--------------------------------------------------------------------------------

newtype FrameHandler =
  FrameHandler { unFrameHandler :: forall s. ScopedFrameHandler s }

mkFrameHandler :: (forall s. ScopedFrameHandler s) -> FrameHandler
mkFrameHandler = FrameHandler

data ScopedFrameHandler s =
  ScopedFrameHandler
    { -- ^ Tag to match.  Only matching frames with a matching tag will be
      -- handled.
      fhTag   :: Tag
      -- ^ What to do before parsing the frame, after matching the tag.
    , fhBegin :: Ivory (AllocEffects s) ()
      -- ^ What to do with a byte of frame data.  Can use the index.
    , fhData  :: Uint8 -> Sint32 -> Ivory (AllocEffects s) ()
      -- ^ What to do at the end of the frame.
    , fhEnd   :: Ivory (AllocEffects s) ()
    }

decodes :: forall s0 s1 . [FrameHandler]
        -> Ref s1 Hx
        -> Uint8
        -> Ivory (AllocEffects s0) ()
decodes fhs state b = do
  -- State before decoding byte.
  st0  <- state ~>* fstate
  off  <- state ~>* offset

  byte <- call decodeSM state b

  -- State after decoding byte.
  st1  <- state ~>* fstate
  tag  <- state ~>* ftag

  -- Run each framehandler for which the tag matches.
  let fhLookup :: (ScopedFrameHandler s0 -> Ivory (AllocEffects s0) ())
               -> Ivory (AllocEffects s0) ()
      fhLookup k =
        mapM_ (\(FrameHandler fh) -> when (tag ==? fhTag fh)
                           (k fh))
              fhs

  cond_
    [   -- Frame ended.
        (st0 ==? hxstate_progress) .&& (st1 ==? hxstate_tag)
    ==> fhLookup fhEnd
        -- Getting tag.
    ,   (st0 ==? hxstate_tag)
    ==> fhLookup fhBegin
        -- Got a frame byte: process.
    ,   (st0 ==? hxstate_progress) .|| (st0 ==? hxstate_esc)
    ==> fhLookup (\fh -> fhData fh byte off)
        -- Idle otherwise.
    ,   true
    ==> return ()
   ]

-- | Decode a frame given a frame state and byte and a set of framehandler
-- functions.
decode :: FrameHandler
       -> Ref s1 Hx
       -> Uint8
       -> Ivory (AllocEffects s0) ()
decode fh = decodes [fh]

--------------------------------------------------------------------------------

-- | Takes a tag, frame array, and a 'put' function and encodes according to the
-- hxstream protocol.
encode ::   SingI n
         => Tag
         -> ConstRef s (Array n (Stored Uint8))
         -> (Uint8 -> Ivory (AllocEffects cs) ())
         -> Ivory (AllocEffects cs) ()
encode tag arr put = do
  put fbo
  put tag
  putencoded
  where
  putencoded = arrayMap $ \ix -> noBreak $ do
    v  <- deref (arr ! ix)
    ifte_ ((v ==? fbo) .|| (v ==? ceo))
          (put ceo >> put (escape v))
          (put v)

--------------------------------------------------------------------------------

hxstreamModule :: Module
hxstreamModule = package "hxstream_state_module" $ do
  defStruct (Proxy :: Proxy "hxstream_state")
  incl decodeSM

--------------------------------------------------------------------------------
