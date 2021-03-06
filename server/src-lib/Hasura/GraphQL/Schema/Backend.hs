{-# LANGUAGE AllowAmbiguousTypes #-}

module Hasura.GraphQL.Schema.Backend where

import           Hasura.Prelude

import           Data.Aeson
import           Data.Has

import qualified Hasura.RQL.IR.Select          as IR
import qualified Hasura.RQL.IR.Update          as IR

import           Hasura.GraphQL.Parser         (Definition, EnumValueInfo, FieldParser,
                                                InputFieldsParser, Kind (..), Opaque, Parser,
                                                UnpreparedValue (..))
import           Hasura.GraphQL.Parser.Class
import           Hasura.GraphQL.Schema.Common
import           Hasura.RQL.Types              hiding (EnumValueInfo)
import           Language.GraphQL.Draft.Syntax (Nullability)


class Backend b => BackendSchema (b :: BackendType) where
  columnParser
    :: (MonadSchema n m, MonadError QErr m)
    => ColumnType b
    -> Nullability
    -> m (Parser 'Both n (Opaque (ColumnValue b)))
  -- | The "path" argument for json column fields
  jsonPathArg
    :: MonadParse n
    => ColumnType b
    -> InputFieldsParser n (Maybe (IR.ColumnOp b))
  orderByOperators
    :: NonEmpty (Definition EnumValueInfo, (BasicOrderType b, NullsOrderType b))
  comparisonExps
    :: (MonadSchema n m, MonadError QErr m)
    => ColumnType b
    -> m (Parser 'Input n [ComparisonExp b])
  updateOperators
    :: (MonadSchema n m, MonadTableInfo r m)
    => TableName b
    -> UpdPermInfo b
    -> m (Maybe (InputFieldsParser n [(Column b, IR.UpdOpExpG (UnpreparedValue b))]))
  parseScalarValue
    :: (MonadError QErr m)
    => ColumnType b
    -> Value
    -> m (ScalarValue b)
  -- TODO: THIS IS A TEMPORARY FIX
  -- while offset is exposed in the schema as a GraphQL Int, which
  -- is a bounded Int32, previous versions of the code used to also
  -- silently accept a string as an input for the offset as a way to
  -- support int64 values (postgres bigint)
  -- a much better way of supporting this would be to expose the
  -- offset in the code as a postgres bigint, but for now, to avoid
  -- a breaking change, we are defining a custom parser that also
  -- accepts a string
  offsetParser :: MonadParse n => Parser 'Both n (SQLExpression b)
  mkCountType :: Maybe Bool -> Maybe [Column b] -> CountType b
  aggregateOrderByCountType :: ScalarType b
  -- | Computed field parser
  computedField
    :: ( BackendSchema b
       , MonadSchema n m
       , MonadTableInfo r m
       , MonadRole r m
       , Has QueryContext r
       )
    => ComputedFieldInfo b
    -> SelPermInfo b
    -> m (Maybe (FieldParser n (AnnotatedField b)))
  -- | The 'node' root field of a Relay request.
  node
    :: ( BackendSchema b
       , MonadSchema n m
       , MonadTableInfo r m
       , MonadRole r m
       , Has QueryContext r
       )
    => m (Parser 'Output n (HashMap (TableName b) (SourceName, SourceConfig b, SelPermInfo b, PrimaryKeyColumns b, AnnotatedFields b)))
  remoteRelationshipField
    :: ( BackendSchema b
       , MonadSchema n m
       , MonadRole r m
       , MonadError QErr m
       , Has QueryContext r
       )
    => RemoteFieldInfo b
    -> m (Maybe [FieldParser n (AnnotatedField b)])

type ComparisonExp b = OpExpG b (UnpreparedValue b)
