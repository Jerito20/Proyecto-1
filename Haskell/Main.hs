{-# LANGUAGE RecordWildCards #-}

module Main where

import qualified Data.ByteString as BS
import qualified Data.ByteString.Char8 as BC
import Data.Bits (testBit)
import Data.Word (Word8)
import System.Environment (getArgs)
import Text.Printf (printf)

-- ============================================================
-- 1. Representation of a PBM P4 image
-- ============================================================

data PBM = PBM
  { pbmWidth  :: Int
  , pbmHeight :: Int
  , pbmRaster :: BS.ByteString
  }

rowBytes :: PBM -> Int
rowBytes PBM{..} = (pbmWidth + 7) `div` 8

-- ============================================================
-- 2. PBM P4 header parsing
-- ============================================================

isWhite :: Word8 -> Bool
isWhite b = b `elem` [9, 10, 11, 12, 13, 32]

skipComment :: BS.ByteString -> Int -> Int
skipComment bs i
  | i >= BS.length bs = i
  | BS.index bs i == 10 = i + 1
  | otherwise = skipComment bs (i + 1)

skipHeaderJunk :: BS.ByteString -> Int -> Int
skipHeaderJunk bs i
  | i >= BS.length bs = i
  | isWhite (BS.index bs i) = skipHeaderJunk bs (i + 1)
  | BS.index bs i == 35    = skipHeaderJunk bs (skipComment bs (i + 1)) -- '#'
  | otherwise              = i

scanTokenEnd :: BS.ByteString -> Int -> Int
scanTokenEnd bs i
  | i >= BS.length bs = i
  | isWhite (BS.index bs i) = i
  | BS.index bs i == 35 = i
  | otherwise = scanTokenEnd bs (i + 1)

nextToken :: BS.ByteString -> Int -> Either String (BS.ByteString, Int)
nextToken bs pos =
  let start = skipHeaderJunk bs pos
      end   = scanTokenEnd bs start
  in if start >= BS.length bs
       then Left "Unexpected end of file while reading PBM header."
       else Right (BS.take (end - start) (BS.drop start bs), end)

parseIntToken :: String -> BS.ByteString -> Either String Int
parseIntToken name tok =
  case reads (BC.unpack tok) of
    [(n, "")] | n > 0 -> Right n
    _ -> Left ("Invalid " ++ name ++ " in PBM header: " ++ BC.unpack tok)

-- After the height, raw P4 data begins after the mandatory whitespace.
-- We consume exactly one separator, except CRLF which is treated as one newline.
rasterStart :: BS.ByteString -> Int -> Either String Int
rasterStart bs pos
  | pos >= BS.length bs = Left "Missing raster separator after PBM dimensions."
  | BS.index bs pos == 13
    && pos + 1 < BS.length bs
    && BS.index bs (pos + 1) == 10 = Right (pos + 2)
  | isWhite (BS.index bs pos) = Right (pos + 1)
  | otherwise = Left "PBM header is not followed by whitespace before raster data."

parsePBM :: BS.ByteString -> Either String PBM
parsePBM bs = do
  (magic, p1) <- nextToken bs 0
  if magic /= BC.pack "P4"
    then Left "The file is not PBM P4."
    else pure ()

  (wTok, p2) <- nextToken bs p1
  (hTok, p3) <- nextToken bs p2
  w <- parseIntToken "width" wTok
  h <- parseIntToken "height" hTok
  start <- rasterStart bs p3

  let bytesPerRow = (w + 7) `div` 8
      expected     = bytesPerRow * h
      available    = BS.length bs - start

  if available < expected
    then Left $ "Incomplete PBM raster: expected " ++ show expected
             ++ " bytes, found " ++ show available ++ "."
    else Right $ PBM w h (BS.take expected (BS.drop start bs))

loadPBM :: FilePath -> IO PBM
loadPBM path = do
  bytes <- BS.readFile path
  case parsePBM bytes of
    Left err  -> ioError (userError err)
    Right img -> pure img

-- ============================================================
-- 3. Access to an individual pixel
--    P4: the leftmost pixel in every byte is the most-significant bit.
-- ============================================================

pixel :: PBM -> Int -> Int -> Bool
pixel img@PBM{..} x y
  | x < 0 || x >= pbmWidth || y < 0 || y >= pbmHeight = False
  | otherwise =
      let bytesPerRow = rowBytes img
          byteIndex   = y * bytesPerRow + (x `div` 8)
          bitIndex    = 7 - (x `mod` 8)
          b           = BS.index pbmRaster byteIndex
      in testBit b bitIndex

-- ============================================================
-- 4. Discrete function f(x) and height structure M
-- ============================================================

-- Count consecutive black pixels from bottom to top.
f :: PBM -> Int -> Int
f img@PBM{..} x =
  length
    . takeWhile id
    $ map (pixel img x) [pbmHeight - 1, pbmHeight - 2 .. 0]

-- Functional transformation explicitly requested in the assignment:
-- M = map f [0 .. width - 1]
heightStructure :: PBM -> [Int]
heightStructure img@PBM{..} = map (f img) [0 .. pbmWidth - 1]

-- Riemann sum with Delta x = 1 pixel.
riemannArea :: [Int] -> Int
riemannArea = sum

-- ============================================================
-- 5. Compact visualization of the original PBM
-- ============================================================

-- Average black-pixel density inside one terminal cell.
cellDensity :: PBM -> Int -> Int -> Int -> Int -> Double
cellDensity img@PBM{..} outW outH ox oy =
  let x0 = ox * pbmWidth `div` outW
      x1 = ((ox + 1) * pbmWidth `div` outW) - 1
      y0 = oy * pbmHeight `div` outH
      y1 = ((oy + 1) * pbmHeight `div` outH) - 1
      coords = [(x, y) | y <- [y0 .. y1], x <- [x0 .. x1]]
      black  = length [() | (x, y) <- coords, pixel img x y]
      total  = length coords
  in if total == 0 then 0 else fromIntegral black / fromIntegral total

shade :: Double -> Char
shade d
  | d < 0.10 = ' '
  | d < 0.30 = '░'
  | d < 0.55 = '▒'
  | d < 0.80 = '▓'
  | otherwise = '█'

renderPBM :: PBM -> Int -> Int -> String
renderPBM img@PBM{..} requestedW requestedH =
  let outW = max 1 (min requestedW pbmWidth)
      outH = max 1 (min requestedH pbmHeight)
      oneRow oy = [shade (cellDensity img outW outH ox oy) | ox <- [0 .. outW - 1]]
  in unlines [oneRow oy | oy <- [0 .. outH - 1]]

-- ============================================================
-- 6. Visualization of M[x] = f(x)
-- ============================================================

average :: [Int] -> Int
average [] = 0
average xs = sum xs `div` length xs

compressHeights :: Int -> [Int] -> [Int]
compressHeights requestedW xs
  | null xs = []
  | otherwise =
      let n    = length xs
          outW = max 1 (min requestedW n)
          bucket i =
            let start = i * n `div` outW
                end   = (i + 1) * n `div` outW
            in take (end - start) (drop start xs)
      in map (average . bucket) [0 .. outW - 1]

renderHeightFunction :: [Int] -> Int -> Int -> String
renderHeightFunction hs requestedW requestedH
  | null hs = ""
  | otherwise =
      let compact = compressHeights requestedW hs
          maxH    = maximum compact
          outH    = max 1 requestedH
          filled level value = value * outH >= level * maxH
          oneRow level = [if filled level v then '█' else ' ' | v <- compact]
      in unlines [oneRow level | level <- [outH, outH - 1 .. 1]]

-- ============================================================
-- 7. Ten sample positions distributed over the domain
-- ============================================================

samplePositions :: Int -> Int -> [Int]
samplePositions count width
  | count <= 1 = [0]
  | width <= 1 = replicate count 0
  | otherwise =
      [ (i * (width - 1) + (count - 1) `div` 2) `div` (count - 1)
      | i <- [0 .. count - 1]
      ]

showSamples :: [Int] -> IO ()
showSamples hs = do
  let positions = samplePositions 10 (length hs)
  mapM_ showOne (zip [0 :: Int ..] positions)
  where
    showOne (i, x) =
      printf "x_%d = %d -> f(x_%d) = %d pixels\n" i x i (hs !! x)

-- ============================================================
-- 8. Main program
-- ============================================================

main :: IO ()
main = do
  args <- getArgs
  let fileName = case args of
        (p:_) -> p
        []    -> "curva_binaria_P4.pbm"

  img <- loadPBM fileName
  let m    = heightStructure img
      area = riemannArea m

  putStrLn "============================================================"
  putStrLn "PBM P4 - Riemann sum using Functional Programming"
  putStrLn "============================================================"
  printf "Dimensions: %d x %d pixels\n" (pbmWidth img) (pbmHeight img)
  printf "Bytes per raster row: %d\n" (rowBytes img)
  printf "Number of heights in M: %d\n" (length m)
  printf "Area = sum M = %d square pixels\n" area
  putStrLn $ "First 15 values of M: " ++ show (take 15 m)

  putStrLn "\nCompact representation of the original PBM:"
  putStrLn "(Each terminal character summarizes a rectangular block of source pixels.)"
  putStr $ renderPBM img 90 30

  putStrLn "\nGraph of the height function M[x] = f(x):"
  putStr $ renderHeightFunction m 90 20

  putStrLn "\n10 positions distributed over the domain:"
  showSamples m
