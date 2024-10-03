CREATE DATABASE IF NOT EXISTS raw;
CREATE TABLE raw.receipts
(
  `blockNumber` Int64,
  `blockTimestamp` DateTime,
  `blockHash` String,
  `contractAddress` String,
  `cumulativeGasUsed` Int256,
  `effectiveGasPrice` Int256,
  `from` String,
  `gasUsed` Int256,
  `logs` Array(Tuple(    address String,    blockHash String,   blockNumber Int64,   data String,   logIndex String,    removed Bool,   topics Array(String),   transactionHash String,    transactionIndex String)),
  `logsBloom` String,
  `status` String,
  `to` String,
  `transactionHash` String,
  `transactionIndex` Int64,
  `type` String,
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(blockTimestamp)
ORDER BY blockTimestamp;

insert into raw.receipts
select
  blockNumber,
  parseDateTimeBestEffort(blockTimestamp) as blockTimestamp,
  blockHash,
  contractAddress,
  reinterpretAsInt256(reverse(unhex(substring(cumulativeGasUsed,3)))) as cumulativeGasUsed,
  reinterpretAsInt256(reverse(unhex(substring(effectiveGasPrice,3)))) as effectiveGasPrice,
  from,
  reinterpretAsInt256(reverse(unhex(substring(gasUsed,3)))) as gasUsed,
   arrayMap(
    log_tuple -> (
      log_tuple.address,              -- log address
      log_tuple.blockHash,            -- log blockHash
      -- Convert hex blockNumber to Int64
      reinterpretAsInt64(reverse(unhex(substring(log_tuple.blockNumber, 3)))),
      log_tuple.data,                 -- log data
      log_tuple.logIndex,             -- log logIndex
      log_tuple.removed,              -- log removed
      log_tuple.topics,               -- log topics
      log_tuple.transactionHash,      -- log transactionHash
      reinterpretAsInt64(reverse(unhex(substring(log_tuple.transactionIndex, 3)))),
    ), logs) AS logs,
  logsBloom,
  status,
  to,
  transactionHash,
  reinterpretAsInt64(reverse(unhex(substring(transactionIndex,3)))) as transactionIndex,
  type,
from file('./receipts_*');


