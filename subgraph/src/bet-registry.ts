import { BigInt } from "@graphprotocol/graph-ts";
import { Bet } from "../generated/schema";
import {
  BetCreated,
  BetDeclined,
  BetMatched,
  BetSettled,
  BetCancelled,
  BetForfeited,
  BetRefunded,
} from "../generated/BetRegistry/BetRegistry";
import {
  getOrCreateUser,
  getOrCreatePlatform,
  getOrCreateDailyStats,
} from "./utils";

export function handleBetCreated(event: BetCreated): void {
  let betId = event.params.betId.toString();
  let bet = new Bet(betId);

  bet.betType = event.params.betType == 0 ? "OPEN" : "PRIVATE";
  bet.status = "OPEN";
  bet.token = event.params.token;
  bet.stake = event.params.stake;
  bet.arbiterFee = event.params.arbiterFee;
  bet.platformFee = event.params.platformFee;
  bet.payout = event.params.stake.times(BigInt.fromI32(2))
    .minus(event.params.arbiterFee)
    .minus(event.params.platformFee);
  bet.deadline = event.params.deadline;
  if (event.params.betType == 1) {
    bet.pendingChallenger = event.params.challenger;
  }
  bet.condition = "";
  bet.arbiter = event.params.arbiter;
  bet.createdAt = event.block.timestamp;
  bet.createdTx = event.transaction.hash;

  let creator = getOrCreateUser(event.params.creator);
  creator.totalWagered = creator.totalWagered.plus(event.params.stake);
  creator.save();
  bet.creator = creator.id;

  bet.save();

  let platform = getOrCreatePlatform();
  platform.totalBets = platform.totalBets.plus(BigInt.fromI32(1));
  platform.activeBets = platform.activeBets.plus(BigInt.fromI32(1));
  platform.save();

  let stats = getOrCreateDailyStats(event.block.timestamp);
  stats.betsCreated = stats.betsCreated.plus(BigInt.fromI32(1));
  stats.volume = stats.volume.plus(event.params.stake);
  stats.save();
}

export function handleBetMatched(event: BetMatched): void {
  let bet = Bet.load(event.params.betId.toString());
  if (bet == null) return;

  bet.status = "MATCHED";
  bet.matchedAt = event.block.timestamp;

  let challenger = getOrCreateUser(event.params.challenger);
  challenger.totalWagered = challenger.totalWagered.plus(event.params.stake);
  challenger.save();
  bet.challenger = challenger.id;

  bet.save();
}

export function handleBetSettled(event: BetSettled): void {
  let bet = Bet.load(event.params.betId.toString());
  if (bet == null) return;

  bet.status = "SETTLED";
  bet.settledAt = event.block.timestamp;

  let winner = getOrCreateUser(event.params.winner);
  winner.totalEarned = winner.totalEarned.plus(event.params.payout);
  winner.save();
  bet.winner = winner.id;

  getOrCreateUser(event.params.loser);

  bet.save();

  let platform = getOrCreatePlatform();
  platform.activeBets = platform.activeBets.minus(BigInt.fromI32(1));
  platform.totalSettled = platform.totalSettled.plus(BigInt.fromI32(1));
  platform.totalFeesCollected = platform.totalFeesCollected
    .plus(event.params.platformFee);
  platform.save();

  let stats = getOrCreateDailyStats(event.block.timestamp);
  stats.betsSettled = stats.betsSettled.plus(BigInt.fromI32(1));
  stats.feesCollected = stats.feesCollected.plus(event.params.platformFee);
  stats.save();
}

export function handleBetCancelled(event: BetCancelled): void {
  let bet = Bet.load(event.params.betId.toString());
  if (bet == null) return;

  bet.status = "CANCELLED";
  bet.cancelledAt = event.block.timestamp;
  bet.save();

  let creator = getOrCreateUser(event.params.creator);
  creator.totalWagered = creator.totalWagered.minus(event.params.stake);
  creator.save();

  let platform = getOrCreatePlatform();
  platform.activeBets = platform.activeBets.minus(BigInt.fromI32(1));
  platform.totalCancelled = platform.totalCancelled.plus(BigInt.fromI32(1));
  platform.save();

  let stats = getOrCreateDailyStats(event.block.timestamp);
  stats.betsCancelled = stats.betsCancelled.plus(BigInt.fromI32(1));
  stats.save();
}

export function handleBetDeclined(event: BetDeclined): void {
  let bet = Bet.load(event.params.betId.toString());
  if (bet == null) return;

  bet.status = "CANCELLED";
  bet.cancelledAt = event.block.timestamp;
  bet.pendingChallenger = null;
  bet.save();

  let creator = getOrCreateUser(event.params.creator);
  creator.totalWagered = creator.totalWagered.minus(event.params.stake);
  creator.save();

  let platform = getOrCreatePlatform();
  platform.activeBets = platform.activeBets.minus(BigInt.fromI32(1));
  platform.totalCancelled = platform.totalCancelled.plus(BigInt.fromI32(1));
  platform.save();

  let stats = getOrCreateDailyStats(event.block.timestamp);
  stats.betsCancelled = stats.betsCancelled.plus(BigInt.fromI32(1));
  stats.save();
}

export function handleBetForfeited(event: BetForfeited): void {
  let bet = Bet.load(event.params.betId.toString());
  if (bet == null) return;

  bet.status = "FORFEITED";
  bet.settledAt = event.block.timestamp;

  let winner = getOrCreateUser(event.params.winner);
  winner.totalEarned = winner.totalEarned.plus(event.params.payout);
  winner.save();
  bet.winner = winner.id;

  getOrCreateUser(event.params.forfeiter);

  bet.save();

  let platform = getOrCreatePlatform();
  platform.activeBets = platform.activeBets.minus(BigInt.fromI32(1));
  platform.totalForfeited = platform.totalForfeited.plus(BigInt.fromI32(1));
  platform.totalFeesCollected = platform.totalFeesCollected
    .plus(event.params.platformFee);
  platform.save();

  let stats = getOrCreateDailyStats(event.block.timestamp);
  stats.betsForfeited = stats.betsForfeited.plus(BigInt.fromI32(1));
  stats.feesCollected = stats.feesCollected.plus(event.params.platformFee);
  stats.save();
}

export function handleBetRefunded(event: BetRefunded): void {
  let bet = Bet.load(event.params.betId.toString());
  if (bet == null) return;

  bet.status = "TIMEDOUT";
  bet.cancelledAt = event.block.timestamp;
  bet.refundPerParticipant = event.params.refundPerParticipant;
  bet.timeoutFee = event.params.platformFee;
  bet.save();

  let creator = getOrCreateUser(event.params.creator);
  creator.totalWagered = creator.totalWagered.minus(
    bet.stake.minus(event.params.refundPerParticipant)
  );
  creator.save();

  let challenger = getOrCreateUser(event.params.challenger);
  challenger.totalWagered = challenger.totalWagered.minus(
    bet.stake.minus(event.params.refundPerParticipant)
  );
  challenger.save();

  let platform = getOrCreatePlatform();
  platform.activeBets = platform.activeBets.minus(BigInt.fromI32(1));
  platform.totalTimedOut = platform.totalTimedOut.plus(BigInt.fromI32(1));
  platform.totalFeesCollected = platform.totalFeesCollected
    .plus(event.params.platformFee);
  platform.save();

  let stats = getOrCreateDailyStats(event.block.timestamp);
  stats.betsTimedOut = stats.betsTimedOut.plus(BigInt.fromI32(1));
  stats.feesCollected = stats.feesCollected.plus(event.params.platformFee);
  stats.save();
}
