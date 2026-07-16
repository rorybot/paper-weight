/** Feed channel payload — owned by F1/F2. See features/feed/spec.md */

export type FeedPostV1 = {
  readonly id: string;
  readonly handle: string;
  readonly body: string;
  readonly time_label: string;
  readonly accent: string;
};

export type FeedSnapshotV1 = {
  readonly as_of: string;
  readonly stale: boolean;
  readonly posts: readonly FeedPostV1[];
};
