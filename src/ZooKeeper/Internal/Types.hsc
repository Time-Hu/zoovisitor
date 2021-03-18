{-# LANGUAGE CPP #-}

module ZooKeeper.Internal.Types where

import           Control.Exception (bracket_)
import           Control.Monad     (forM)
import           Data.Int
import           Data.Proxy        (Proxy (..))
import           Foreign
import           Foreign.C
import           Z.Data.CBytes     (CBytes)
import qualified Z.Data.CBytes     as CBytes
import qualified Z.Data.Text       as Text
import           Z.Data.Vector     (Bytes)
import qualified Z.Foreign         as Z

#include "hs_zk.h"

-------------------------------------------------------------------------------

newtype ZHandle = ZHandle { unZHandle :: Ptr () }
  deriving (Show, Eq)

newtype ClientID = ClientID { unClientID :: Ptr () }
  deriving (Show, Eq)

newtype ZooLogLevel = ZooLogLevel CInt
  deriving (Eq, Storable)

instance Show ZooLogLevel where
  show ZooLogError = "ERROR"
  show ZooLogWarn  = "WARN"
  show ZooLogInfo  = "INFO"
  show ZooLogDebug = "DEBUG"
  show (ZooLogLevel x) = "ZooLogLevel " ++ show x

pattern ZooLogError, ZooLogWarn, ZooLogInfo, ZooLogDebug :: ZooLogLevel
pattern ZooLogError = ZooLogLevel (#const ZOO_LOG_LEVEL_ERROR)
pattern ZooLogWarn  = ZooLogLevel (#const ZOO_LOG_LEVEL_WARN)
pattern ZooLogInfo  = ZooLogLevel (#const ZOO_LOG_LEVEL_INFO)
pattern ZooLogDebug = ZooLogLevel (#const ZOO_LOG_LEVEL_DEBUG)

-------------------------------------------------------------------------------

-- | ACL consts.
newtype Acl = Acl { unAcl :: CInt }
  deriving (Show, Eq)

pattern ZooPermRead :: Acl
pattern ZooPermRead = Acl (#const ZOO_PERM_READ)

pattern ZooPermWrite :: Acl
pattern ZooPermWrite = Acl (#const ZOO_PERM_WRITE)

pattern ZooPermCreate :: Acl
pattern ZooPermCreate = Acl (#const ZOO_PERM_CREATE)

pattern ZooPermDelete :: Acl
pattern ZooPermDelete = Acl (#const ZOO_PERM_DELETE)

pattern ZooPermAdmin :: Acl
pattern ZooPermAdmin = Acl (#const ZOO_PERM_ADMIN)

pattern ZooPermAll :: Acl
pattern ZooPermAll = Acl (#const ZOO_PERM_ALL)

newtype AclVector = AclVector { unAclVector :: Ptr () }
  deriving (Show, Eq)

-- | This is a completely open ACL
foreign import ccall unsafe "hs_zk.h &ZOO_OPEN_ACL_UNSAFE"
  zooOpenAclUnsafe :: AclVector

-- | This ACL gives the world the ability to read.
foreign import ccall unsafe "hs_zk.h &ZOO_READ_ACL_UNSAFE"
  zooReadAclUnsafe :: AclVector

-- | This ACL gives the creators authentication id's all permissions.
foreign import ccall unsafe "hs_zk.h &ZOO_CREATOR_ALL_ACL"
  zooCreatorAllAcl :: AclVector

-------------------------------------------------------------------------------

-- | State Consts
--
-- These constants represent the states of a zookeeper connection. They are
-- possible parameters of the watcher callback.
newtype ZooState = ZooState CInt
  deriving (Eq, Storable)
  deriving newtype (Text.Print)

instance Show ZooState where
  show ZooExpiredSession   = "ExpiredSession"
  show ZooAuthFailed       = "AuthFailed"
  show ZooConnectingState  = "ConnectingState"
  show ZooAssociatingState = "AssociatingState"
  show ZooConnectedState   = "ConnectedState"
  show (ZooState x)        = "ZooState " <> show x

pattern
    ZooExpiredSession, ZooAuthFailed
  , ZooConnectingState, ZooAssociatingState, ZooConnectedState :: ZooState
pattern ZooExpiredSession   = ZooState (#const ZOO_EXPIRED_SESSION_STATE)
pattern ZooAuthFailed       = ZooState (#const ZOO_AUTH_FAILED_STATE)
pattern ZooConnectingState  = ZooState (#const ZOO_CONNECTING_STATE)
pattern ZooAssociatingState = ZooState (#const ZOO_ASSOCIATING_STATE)
pattern ZooConnectedState   = ZooState (#const ZOO_CONNECTED_STATE)

-- TODO
-- pattern ZOO_READONLY_STATE :: ZooState
-- pattern ZOO_READONLY_STATE = ZooState (#const ZOO_READONLY_STATE)
-- pattern ZOO_NOTCONNECTED_STATE :: ZooState
-- pattern ZOO_NOTCONNECTED_STATE = ZooState (#const ZOO_NOTCONNECTED_STATE)

-------------------------------------------------------------------------------

-- | Watch Types
--
-- These constants indicate the event that caused the watch event. They are
-- possible values of the first parameter of the watcher callback.
newtype ZooEvent = ZooEvent CInt
  deriving (Eq, Storable)

instance Show ZooEvent where
  show ZooCreateEvent     = "CreateEvent"
  show ZooDeleteEvent     = "DeleteEvent"
  show ZooChangedEvent    = "ChangedEvent"
  show ZooChildEvent      = "ChildEvent"
  show ZooSessionEvent    = "SessionEvent"
  show ZooNoWatchingEvent = "NoWatchingEvent"
  show (ZooEvent x)       = "ZooEvent " <> show x

-- | A node has been created.
--
-- This is only generated by watches on non-existent nodes. These watches
-- are set using 'ZooKeeper.zooWatchExists'.
pattern ZooCreateEvent :: ZooEvent
pattern ZooCreateEvent = ZooEvent (#const ZOO_CREATED_EVENT)

-- | A node has been deleted.
--
-- This is only generated by watches on nodes. These watches
-- are set using 'ZooKeeper.zooWatchExists' and 'ZooKeeper.zooWatchGet'.
pattern ZooDeleteEvent :: ZooEvent
pattern ZooDeleteEvent = ZooEvent (#const ZOO_DELETED_EVENT)

-- | A node has changed.
--
-- This is only generated by watches on nodes. These watches
-- are set using 'ZooKeeper.zooWatchExists' and 'ZooKeeper.zooWatchGet'.
pattern ZooChangedEvent :: ZooEvent
pattern ZooChangedEvent = ZooEvent (#const ZOO_CHANGED_EVENT)

-- A change as occurred in the list of children.
--
-- This is only generated by watches on the child list of a node. These watches
-- are set using 'ZooKeeper.zooWatchGetChildren' or 'ZooKeeper.zooWatchGetChildren2'.
pattern ZooChildEvent :: ZooEvent
pattern ZooChildEvent = ZooEvent (#const ZOO_CHILD_EVENT)

-- | A session has been lost.
--
-- This is generated when a client loses contact or reconnects with a server.
pattern ZooSessionEvent :: ZooEvent
pattern ZooSessionEvent = ZooEvent (#const ZOO_SESSION_EVENT)

-- | A watch has been removed.
--
-- This is generated when the server for some reason, probably a resource
-- constraint, will no longer watch a node for a client.
pattern ZooNoWatchingEvent :: ZooEvent
pattern ZooNoWatchingEvent = ZooEvent (#const ZOO_NOTWATCHING_EVENT)

-------------------------------------------------------------------------------

-- | These modes are used by zoo_create to affect node create.
newtype CreateMode = CreateMode { unCreateMode :: CInt }
  deriving (Show, Eq)

pattern ZooPersistent :: CreateMode
pattern ZooPersistent = CreateMode 0

-- | The znode will be deleted upon the client's disconnect.
pattern ZooEphemeral :: CreateMode
pattern ZooEphemeral = CreateMode (#const ZOO_EPHEMERAL)

pattern ZooSequence :: CreateMode
pattern ZooSequence = CreateMode (#const ZOO_SEQUENCE)

-- TODO
--pattern ZooPersistent :: CreateMode
--pattern ZooPersistent = CreateMode (#const ZOO_PERSISTENT)
--
--pattern ZooPersistentSequential :: CreateMode
--pattern ZooPersistentSequential = CreateMode (#const ZOO_PERSISTENT_SEQUENTIAL)
--
--pattern ZooEphemeralSequential :: CreateMode
--pattern ZooEphemeralSequential = CreateMode (#const ZOO_EPHEMERAL_SEQUENTIAL)
--
--pattern ZooContainer :: CreateMode
--pattern ZooContainer = CreateMode (#const ZOO_CONTAINER)
--
--pattern ZooPersistentWithTTL :: CreateMode
--pattern ZooPersistentWithTTL = CreateMode (#const ZOO_PERSISTENT_WITH_TTL)
--
--pattern ZooPersistentSequentialWithTTL :: CreateMode
--pattern ZooPersistentSequentialWithTTL = CreateMode (#const ZOO_PERSISTENT_SEQUENTIAL_WITH_TTL)

data Stat = Stat
  { statCzxid          :: Int64
  , statMzxid          :: Int64
  , statCtime          :: Int64
  , statMtime          :: Int64
  , statVersion        :: Int32
  , statCversion       :: Int32
  , statAversion       :: Int32
  , statEphemeralOwner :: Int64
  , statDataLength     :: Int32
  , statNumChildren    :: Int32
  , statPzxid          :: Int64
  } deriving (Show, Eq)

peekStat' :: Ptr Stat -> IO Stat
peekStat' ptr = Stat
  <$> (#peek stat_t, czxid) ptr
  <*> (#peek stat_t, mzxid) ptr
  <*> (#peek stat_t, ctime) ptr
  <*> (#peek stat_t, mtime) ptr
  <*> (#peek stat_t, version) ptr
  <*> (#peek stat_t, cversion) ptr
  <*> (#peek stat_t, aversion) ptr
  <*> (#peek stat_t, ephemeralOwner) ptr
  <*> (#peek stat_t, dataLength) ptr
  <*> (#peek stat_t, numChildren) ptr
  <*> (#peek stat_t, pzxid) ptr

peekStat :: Ptr Stat -> IO Stat
peekStat ptr = peekStat' ptr <* free ptr

newtype StringVector = StringVector [CBytes]
  deriving Show

peekStringVector :: Ptr StringVector -> IO StringVector
peekStringVector ptr = bracket_ (return ()) (free ptr) $ do
  -- NOTE: Int32 is necessary, since count is int32_t in c
  count <- fromIntegral @Int32 <$> (#peek string_vector_t, count) ptr
  StringVector <$> forM [0..count-1] (peekStringVectorIdx ptr)

peekStringVectorIdx :: Ptr StringVector -> Int -> IO CBytes
peekStringVectorIdx ptr offset = do
  ptr' <- (#peek string_vector_t, data) ptr
  data_ptr <- peek $ ptr' `plusPtr` (offset * (sizeOf ptr'))
  CBytes.fromCString data_ptr <* free data_ptr

-------------------------------------------------------------------------------
-- Callback datas

data HsWatcherCtx = HsWatcherCtx
  { watcherCtxZHandle :: ZHandle
  , watcherCtxType    :: ZooEvent
  , watcherCtxState   :: ZooState
  , watcherCtxPath    :: Maybe CBytes
  } deriving Show

hsWatcherCtxSize :: Int
hsWatcherCtxSize = (#size hs_watcher_ctx_t)

peekHsWatcherCtx :: Ptr HsWatcherCtx -> IO HsWatcherCtx
peekHsWatcherCtx ptr = do
  zh_ptr <- (#peek hs_watcher_ctx_t, zh) ptr
  event_type <-(#peek hs_watcher_ctx_t, type) ptr
  connect_state <- (#peek hs_watcher_ctx_t, state) ptr
  path_ptr <- (#peek hs_watcher_ctx_t, path) ptr
  path <- if path_ptr == nullPtr
             then return Nothing
             else Just <$> CBytes.fromCString path_ptr <* free path_ptr
  return $ HsWatcherCtx (ZHandle zh_ptr) event_type connect_state path

class Completion a where
  {-# MINIMAL csize, peekRet, peekData #-}
  csize :: Proxy a -> Int
  peekRet :: Ptr a -> IO CInt
  peekData :: Ptr a -> IO a

newtype StringCompletion = StringCompletion { strCompletionValue :: CBytes }
  deriving Show

instance Completion StringCompletion where
  csize _ = (#size hs_string_completion_t)
  peekRet ptr = (#peek hs_string_completion_t, rc) ptr
  peekData ptr = do
    value_ptr <- (#peek hs_string_completion_t, value) ptr
    value <- CBytes.fromCString value_ptr <* free value_ptr
    return $ StringCompletion value

data DataCompletion = DataCompletion
  { dataCompletionValue :: Maybe Bytes
  , dataCompletionStat  :: Stat
  } deriving (Show, Eq)

instance Completion DataCompletion where
  csize _ = (#size hs_data_completion_t)
  peekRet ptr = (#peek hs_data_completion_t, rc) ptr
  peekData ptr = do
    val_ptr <- (#peek hs_data_completion_t, value) ptr
    val_len :: CInt <- (#peek hs_data_completion_t, value_len) ptr
    val <- if val_len >= 0
              then Just <$> Z.fromPtr val_ptr (fromIntegral val_len) <* free val_ptr
              else return Nothing
    stat_ptr <- (#peek hs_data_completion_t, stat) ptr
    stat <- peekStat stat_ptr
    return $ DataCompletion val stat

newtype StatCompletion = StatCompletion { statCompletionStat :: Stat }
  deriving (Show, Eq)

instance Completion StatCompletion where
  csize _ = (#size hs_stat_completion_t)
  peekRet ptr = (#peek hs_stat_completion_t, rc) ptr
  peekData ptr = do
    stat_ptr <- (#peek hs_stat_completion_t, stat) ptr
    stat <- peekStat stat_ptr
    return $ StatCompletion stat

newtype VoidCompletion = VoidCompletion ()

instance Completion VoidCompletion where
  csize _ = (#size hs_void_completion_t)
  peekRet ptr = (#peek hs_stat_completion_t, rc) ptr
  peekData _ = return $ VoidCompletion ()

newtype StringsCompletion = StringsCompletion StringVector
  deriving Show

instance Completion StringsCompletion where
  csize _ = (#size hs_strings_completion_t)
  peekRet ptr = (#peek hs_strings_completion_t, rc) ptr
  peekData ptr = do
    strs_ptr <- (#peek hs_strings_completion_t, strings) ptr
    vals <- peekStringVector strs_ptr
    return $ StringsCompletion vals

data StringsStatCompletion = StringsStatCompletion
  { strsStatCompletionStrs :: StringVector
  , strsStatCompletionStat :: Stat
  } deriving Show

instance Completion StringsStatCompletion where
  csize _ = (#size hs_strings_stat_completion_t)
  peekRet ptr = (#peek hs_strings_stat_completion_t, rc) ptr
  peekData ptr = do
    strs_ptr <- (#peek hs_strings_stat_completion_t, strings) ptr
    vals <- peekStringVector strs_ptr
    stat_ptr <- (#peek hs_strings_stat_completion_t, stat) ptr
    stat <- peekStat stat_ptr
    return $ StringsStatCompletion vals stat

-------------------------------------------------------------------------------

-- This structure holds all the arguments necessary for one op as part
-- of a containing multi_op via 'zoo_multi' or 'zoo_amulti'.
-- This structure should be treated as opaque and initialized via
-- 'zoo_create_op_init', 'zoo_delete_op_init', 'zoo_set_op_init'
-- and 'zoo_check_op_init'.
data ZooOp

zooOpSize :: Int
zooOpSize = (#size zoo_op_t)
