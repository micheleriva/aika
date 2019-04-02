{-# LANGUAGE OverloadedStrings #-}

import Data.Map (fromList, findWithDefault, Map, insert)
import Control.Concurrent.STM
import Control.Concurrent (forkIO)
import Network (listenOn, withSocketsDo, accept, PortID(..), Socket)
import Prelude hiding (lookup, take)
import Data.ByteString.Char8 (ByteString, pack)
import System.IO (Handle, hSetBinaryMode, hSetBuffering, BufferMode(..))
import Data.Attoparsec.ByteString.Char8 hiding (takeTill)
import qualified Data.ByteString as S

type Value = ByteString
type Key   = ByteString
type DB    = Map Key Value

data Command = Get Key
             | Set Key Value
             | Unknown
             deriving (Eq, Show)

data Reply = Bulk (Maybe ByteString)
           | MultiBulk (Maybe [Reply])
           deriving (Eq, Show)

version :: ByteString
version = "0.0.1"

crlf :: ByteString
crlf = "\r\n"

ok :: ByteString
ok = "+OK\r\n"

bulk :: Parser Reply
bulk = Bulk <$> do
  len <- char '$' *> signed decimal <* endOfLine
  if len < 0
    then return Nothing
    else Just <$> take len <* endOfLine

multibulk :: Parser Reply
multibulk = MultiBulk <$> do
  len <- char '*' *> signed decimal <* endOfLine
  if len < 0
    then return Nothing
    else Just <$> count len replyParser

atomRead :: TVar a -> IO a
atomRead = atomically . readTVar

updateValue :: (DB -> DB) -> TVar DB -> IO ()
updateValue fn x = atomically $ modifyTVar x fn

parseReply :: Reply -> Maybe Command
parseReply (MultiBulk (Just xs)) =
  case xs of
    [Bulk (Just "get"), Bulk (Just a)] 
      -> Just $ Get a
    [Bulk (Just "set"), Bulk (Just a), Bulk (Just b)] 
      -> Just $ Set a b
    _ 
      -> Just Unknown
parseReply _ = Nothing

replyParser :: Parser Reply
replyParser = choice [bulk, multibulk]

sockHandler :: Socket -> TVar DB -> IO ()
sockHandler sock db = do
  (handle, _, _) <- accept sock
  hSetBuffering handle NoBuffering
  hSetBinaryMode handle True
  _ <- forkIO $ commandProcessor handle db
  sockHandler sock db

commandProcessor :: Handle -> TVar DB -> IO ()
commandProcessor handle db = do
  reply <- hGetReplies handle replyParser
  let command = parseReply reply
  runCommand handle command db
  commandProcessor handle db

hGetReplies :: Handle -> Parser a -> IO a
hGetReplies h parser = go S.empty
  where
    go rest = do
      parseResult <- parseWith readMore parser rest
      case parseResult of
        Fail _ _ s -> error s
        Partial{}  -> error "error: partial"
        Done _ r   -> return r
    readMore = S.hGetSome h (4*1024)

runCommand :: Handle -> Maybe Command -> TVar DB -> IO ()
runCommand handle (Just (Get key)) db = do
    m <- atomRead db
    let value = getValue m key
    S.hPutStr handle $ S.concat ["$", valLength value, crlf, value, crlf]
        where
            valLength :: Value -> ByteString
            valLength = pack . show . S.length
runCommand handle (Just (Set key value)) db = do
    updateValue (insert key value) db
    S.hPutStr handle ok
runCommand handle (Just Unknown) _ =
  S.hPutStr handle $ S.concat ["-ERR ", "unknown command", crlf]
runCommand _ Nothing _ = return ()

getValue :: DB -> Key -> Value
getValue db k = findWithDefault "null" k db

main :: IO ()
main = withSocketsDo $ do
  database <- atomically $ newTVar $ fromList [("__version__", version)]
  sock <- listenOn $ PortNumber 9919
  putStrLn "Listening on localhost:9919"
  sockHandler sock database