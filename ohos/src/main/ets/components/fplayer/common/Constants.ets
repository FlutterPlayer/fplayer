/**
 * 播放器的状态，与 fplayer Dart 侧 FState 枚举顺序一致。
 */
export enum PlayerState {
  unkown = -1,
  idle = 0,
  initialized = 1,
  asyncPreparing = 2,
  prepared = 3,
  started = 4,
  paused = 5,
  completed = 6,
  stopped = 7,
  error = 8,
  end = 9,
}


export class OptionsCategory {
  static readonly OPT_CATEGORY_FORMAT = 1;
  static readonly OPT_CATEGORY_CODEC = 2;
  static readonly OPT_CATEGORY_SWS = 3;
  static readonly OPT_CATEGORY_PLAYER = 4;
}
