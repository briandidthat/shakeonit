import { BigInt } from "@graphprotocol/graph-ts";
import {
  Deposited,
  Withdrawn,
  Locked,
  Unlocked,
  Credited,
  Debited,
} from "../generated/UserVault/UserVault";
import { getOrCreateUser, getOrCreateBalance } from "./utils";

export function handleDeposited(event: Deposited): void {
  getOrCreateUser(event.params.user);
  let balance = getOrCreateBalance(event.params.user, event.params.token);
  balance.available = balance.available.plus(event.params.amount);
  balance.save();
}

export function handleWithdrawn(event: Withdrawn): void {
  let balance = getOrCreateBalance(event.params.user, event.params.token);
  balance.available = balance.available.minus(event.params.amount);
  balance.save();
}

export function handleLocked(event: Locked): void {
  let balance = getOrCreateBalance(event.params.user, event.params.token);
  balance.available = balance.available.minus(event.params.amount);
  balance.locked = balance.locked.plus(event.params.amount);
  balance.save();
}

export function handleUnlocked(event: Unlocked): void {
  let balance = getOrCreateBalance(event.params.user, event.params.token);
  balance.locked = balance.locked.minus(event.params.amount);
  balance.available = balance.available.plus(event.params.amount);
  balance.save();
}

export function handleCredited(event: Credited): void {
  getOrCreateUser(event.params.user);
  let balance = getOrCreateBalance(event.params.user, event.params.token);
  balance.available = balance.available.plus(event.params.amount);
  balance.save();
}

export function handleDebited(event: Debited): void {
  let balance = getOrCreateBalance(event.params.user, event.params.token);
  balance.locked = balance.locked.minus(event.params.amount);
  balance.save();
}
