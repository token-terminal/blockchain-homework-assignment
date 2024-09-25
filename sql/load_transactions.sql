CREATE DATABASE IF NOT EXISTS raw;

CREATE TABLE raw.transactions
(
  `blockTimestamp` DateTime,
  `blockHash` Nullable(String),
  `blockNumber` Int64,
  `from` String,
  `gas` Int256,
  `gasPrice` Int256,
  `hash` String,
  `input` String,
  `nonce` String,
  `to` String,
  `transactionIndex` Int64,
  `value` Nullable(String),
  `type` Nullable(String),
  `chainId` Nullable(String),
  `v` Nullable(String),
  `r` Nullable(String),
  `s` Nullable(String),
  `maxFeePerGas` Int256,
  `maxPriorityFeePerGas` Nullable(Int256),
  `accessList` Array(Nullable(String)),
  `yParity` Nullable(String)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(blockTimestamp)
ORDER BY blockTimestamp;


insert into raw.transactions
select
  parseDateTimeBestEffort(blockTimestamp) as blockTimestamp,
  blockHash,
  blockNumber,
  from,
  reinterpretAsInt256(reverse(unhex(substring(gas,3)))) as gas,
  reinterpretAsInt256(reverse(unhex(substring(gasPrice,3)))) as gasPrice,
  hash ,
  input ,
  nonce ,
  to ,
  reinterpretAsInt64(reverse(unhex(substring(transactionIndex,3)))) as transactionIndex,
  value,
  type ,
  chainId,
  v,
  r,
  s,
  reinterpretAsInt256(reverse(unhex(substring(maxFeePerGas,3)))) as maxFeePerGas,
  reinterpretAsInt256(reverse(unhex(substring(maxPriorityFeePerGas,3)))) as maxPriorityFeePerGas,
  accessList,
  yParity
from file('./transactions_*');

