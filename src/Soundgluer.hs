{-# LANGUAGE FlexibleContexts #-}

module Soundgluer where

import System.Exit
import System.Directory

import Control.Monad

import qualified Data.Map as M
import qualified Data.Text as T
import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Builder as B

import Data.Int

import Codec.Audio.Wave


waveExtension :: FilePath
waveExtension = ".wav"

pathSeparator :: FilePath
pathSeparator = "/"

langsDirectory :: FilePath
langsDirectory = "lang"

stdLang :: FilePath
stdLang = "std"

waveHeaderPath :: FilePath
waveHeaderPath = langsDirectory ++ pathSeparator ++ "header.wav"


glueSpeech :: String -> [String] -> String-> IO ()
glueSpeech lang phones filePath
        | null phones = return ()
        | otherwise   = do
            phoneAudioMap <- loadLangAudio lang
            waveHeader <- readWaveFile waveHeaderPath
            let gluedSpeech = mconcat $ map (phoneAudioMap M.!) phones
            let phonesWriter = flip B.hPutBuilder gluedSpeech
            writeWaveFile filePath waveHeader phonesWriter


loadLangAudio :: String -> IO (M.Map String B.Builder)
loadLangAudio lang =
    M.union <$> loadLangAudio' lang <*> loadLangAudio' stdLang
  where
    loadLangAudio' lang = do
        let langDirectory = getLangPath lang
        dirWaves <- filter isWave <$> listDirectory langDirectory
        phoneAudioList <- zip <$> (return $ map phoneName dirWaves)
                              <*> forM dirWaves (getAudioData langDirectory)
        return $ M.fromList phoneAudioList


isWave :: FilePath -> Bool
isWave fileName = waveExtension == ( T.unpack
                                   . T.takeEnd (length waveExtension)
                                   . T.pack
                                   $ fileName)

phoneName :: FilePath -> String
phoneName fileName = T.unpack
                   . T.dropEnd (length waveExtension)
                   . T.pack
                   $ fileName

getLangPath :: String -> FilePath
getLangPath lang = langsDirectory ++ pathSeparator ++ lang

getAudioData :: FilePath -> FilePath -> IO B.Builder
getAudioData langDirectory fileName = do
    let wavePath = langDirectory ++ pathSeparator ++ fileName
    waveMetadata <- readWaveFile wavePath
    waveData <- L.readFile wavePath
    let waveHeaderLength = fromIntegral $ waveDataOffset waveMetadata
    return $ B.lazyByteString
           $ L.drop waveHeaderLength waveData

-- GHCi utils
generateHeader :: IO ()
generateHeader = do
    a <- readWaveFile $ (getLangPath stdLang) ++ pathSeparator ++ "-.wav"
    writeWaveFile waveHeaderPath a (\h -> return ())
