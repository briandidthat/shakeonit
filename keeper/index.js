const { ethers } = require("ethers");
const config = require("./config");
const { abi } = require("../artifacts/contracts/BetRegistry.sol/BetRegistry.json");

// ─── Logging ──────────────────────────────────────────────────────────────────

function log(level, msg, data = {}) {
  console.log(JSON.stringify({ ts: new Date().toISOString(), level, msg, ...data }));
}

// ─── Subgraph query ───────────────────────────────────────────────────────────

async function fetchExpiredBetsFromSubgraph(nowTimestamp) {
  const query = `{
    bets(
      where: { status: "MATCHED", deadline_lt: "${nowTimestamp}" }
      first: 1000
      orderBy: deadline
      orderDirection: asc
    ) {
      id
    }
  }`;

  const res = await fetch(config.subgraphUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query }),
  });

  if (!res.ok) throw new Error(`Subgraph request failed: ${res.status}`);
  const { data, errors } = await res.json();
  if (errors) throw new Error(`Subgraph errors: ${JSON.stringify(errors)}`);

  return data.bets.map((b) => BigInt(b.id));
}

// ─── On-chain fallback ────────────────────────────────────────────────────────

async function fetchExpiredBetsOnChain(betRegistry) {
  log("info", "Scanning on-chain events for expired bets (subgraph unavailable)");

  const provider = betRegistry.runner.provider;
  const latestBlock = await provider.getBlockNumber();
  const deployBlock = Number(process.env.DEPLOY_BLOCK || 0);
  const PAGE = 9_000; // stay under the common 10k block RPC limit
  const matchedFilter = betRegistry.filters.BetMatched();
  const now = BigInt(Math.floor(Date.now() / 1000));
  const MATCHED = 1n;
  const CONCURRENCY = 20;
  const results = [];

  for (let from = deployBlock; from <= latestBlock; from += PAGE) {
    const to = Math.min(from + PAGE - 1, latestBlock);
    const events = await betRegistry.queryFilter(matchedFilter, from, to);

    for (let i = 0; i < events.length; i += CONCURRENCY) {
      const slice = events.slice(i, i + CONCURRENCY);
      const bets = await Promise.all(
        slice.map((e) => betRegistry.getBet(e.args.betId))
      );
      for (let j = 0; j < bets.length; j++) {
        const bet = bets[j];
        if (bet.status === MATCHED && bet.deadline < now) {
          results.push(slice[j].args.betId);
        }
      }
    }
  }

  return results;
}

// ─── Batch submission ─────────────────────────────────────────────────────────

function chunk(arr, size) {
  const chunks = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

async function processBatch(betRegistry, betIds, batchIndex) {
  log("info", `Submitting batch ${batchIndex}`, { count: betIds.length, ids: betIds.map(String) });

  if (config.dryRun) {
    log("info", "Dry run — skipping transaction");
    return;
  }

  const tx = await betRegistry.batchClaimTimeout(betIds);
  log("info", `Transaction submitted`, { batch: batchIndex, txHash: tx.hash });

  const receipt = await tx.wait();
  const refunded = receipt.logs.filter(
    (l) => l.topics[0] === betRegistry.interface.getEvent("BetRefunded").topicHash
  ).length;

  log("info", `Batch confirmed`, {
    batch: batchIndex,
    txHash: receipt.hash,
    block: receipt.blockNumber,
    betsRefunded: refunded,
    gasUsed: receipt.gasUsed.toString(),
  });
}

// ─── Main ─────────────────────────────────────────────────────────────────────

async function main() {
  log("info", "Keeper starting", { dryRun: config.dryRun });

  const provider = new ethers.JsonRpcProvider(config.rpcUrl);
  const wallet = new ethers.Wallet(config.privateKey, provider);
  const betRegistry = new ethers.Contract(config.betRegistryAddress, abi, wallet);

  const nowTimestamp = Math.floor(Date.now() / 1000);

  // Fetch expired bet IDs — prefer subgraph, fall back to on-chain scan
  let expiredIds;
  if (config.subgraphUrl) {
    try {
      expiredIds = await fetchExpiredBetsFromSubgraph(nowTimestamp);
      log("info", "Fetched expired bets from subgraph", { count: expiredIds.length });
    } catch (err) {
      log("warn", "Subgraph query failed, falling back to on-chain scan", { error: err.message });
      expiredIds = await fetchExpiredBetsOnChain(betRegistry);
    }
  } else {
    expiredIds = await fetchExpiredBetsOnChain(betRegistry);
  }

  log("info", "Expired bets found", { count: expiredIds.length });

  if (expiredIds.length === 0) {
    log("info", "Nothing to do");
    return;
  }

  const batches = chunk(expiredIds, config.batchSize);
  log("info", `Processing ${batches.length} batch(es)`, { batchSize: config.batchSize });

  let totalRefunded = 0;
  for (let i = 0; i < batches.length; i++) {
    try {
      await processBatch(betRegistry, batches[i], i + 1);
      totalRefunded += batches[i].length;
    } catch (err) {
      log("error", `Batch ${i + 1} failed`, { error: err.message });
    }
  }

  log("info", "Keeper finished", { totalProcessed: totalRefunded });
}

main().catch((err) => {
  log("error", "Fatal error", { error: err.message });
  process.exit(1);
});
