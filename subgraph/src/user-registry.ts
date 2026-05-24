import { BigInt } from "@graphprotocol/graph-ts";
import { User } from "../generated/schema";
import {
  UserRegistered,
  WinRecorded,
  LossRecorded,
} from "../generated/UserRegistry/UserRegistry";
import { getOrCreateUser } from "./utils";

export function handleUserRegistered(event: UserRegistered): void {
  let user = getOrCreateUser(event.params.user);
  user.username = event.params.username;
  user.registeredAt = event.block.timestamp;
  user.save();
}

export function handleWinRecorded(event: WinRecorded): void {
  let user = User.load(event.params.user.toHexString());
  if (user == null) return;
  user.wins = event.params.totalWins;
  user.save();
}

export function handleLossRecorded(event: LossRecorded): void {
  let user = User.load(event.params.user.toHexString());
  if (user == null) return;
  user.losses = event.params.totalLosses;
  user.save();
}
