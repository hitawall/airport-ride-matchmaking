import Pusher from "pusher";
import { env } from "./env";

let _pusher: Pusher | null = null;

export function getPusher() {
  if (!_pusher) {
    _pusher = new Pusher({
      appId: env.pusherAppId,
      key: env.pusherKey,
      secret: env.pusherSecret,
      cluster: env.pusherCluster,
      useTLS: true,
    });
  }
  return _pusher;
}

export function matchChannelName(matchId: string) {
  return `match-${matchId}`;
}
