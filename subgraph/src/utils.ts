import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { User, UserTokenBalance, Platform, DailyStats } from "../generated/schema";

export function getOrCreateUser(address: Bytes): User {
  let id = address.toHexString();
  let user = User.load(id);
  if (user == null) {
    user = new User(id);
    user.wins = BigInt.fromI32(0);
    user.losses = BigInt.fromI32(0);
    user.totalWagered = BigInt.fromI32(0);
    user.totalEarned = BigInt.fromI32(0);
    user.save();
  }
  return user;
}

export function getOrCreateBalance(user: Bytes, token: Bytes): UserTokenBalance {
  let id = user.toHexString() + "-" + token.toHexString();
  let balance = UserTokenBalance.load(id);
  if (balance == null) {
    balance = new UserTokenBalance(id);
    balance.user = user.toHexString();
    balance.token = token;
    balance.available = BigInt.fromI32(0);
    balance.locked = BigInt.fromI32(0);
    balance.save();
  }
  return balance;
}

export function getOrCreatePlatform(): Platform {
  let platform = Platform.load("platform");
  if (platform == null) {
    platform = new Platform("platform");
    platform.totalBets = BigInt.fromI32(0);
    platform.activeBets = BigInt.fromI32(0);
    platform.totalSettled = BigInt.fromI32(0);
    platform.totalCancelled = BigInt.fromI32(0);
    platform.totalForfeited = BigInt.fromI32(0);
    platform.totalTimedOut = BigInt.fromI32(0);
    platform.totalFeesCollected = BigInt.fromI32(0);
    platform.save();
  }
  return platform;
}

export function getOrCreateDailyStats(timestamp: BigInt): DailyStats {
  let daySeconds = 86400;
  let dayId = timestamp.toI32() / daySeconds;
  let dayStartTimestamp = dayId * daySeconds;
  let date = new Date(dayStartTimestamp * 1000);
  let id = date.toISOString().substring(0, 10);

  let stats = DailyStats.load(id);
  if (stats == null) {
    stats = new DailyStats(id);
    stats.date = id;
    stats.betsCreated = BigInt.fromI32(0);
    stats.betsSettled = BigInt.fromI32(0);
    stats.betsCancelled = BigInt.fromI32(0);
    stats.betsForfeited = BigInt.fromI32(0);
    stats.betsTimedOut = BigInt.fromI32(0);
    stats.volume = BigInt.fromI32(0);
    stats.feesCollected = BigInt.fromI32(0);
    stats.save();
  }
  return stats;
}
