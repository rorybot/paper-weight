/** Weather channel payload — owned by W1/W2. See features/weather/spec.md */

export type WeatherUvGradeV1 = "extreme" | "high" | "low";

export type WeatherDayV1 = {
  readonly date: string;
  readonly high_f: number;
  readonly low_f: number;
  readonly summary: string;
};

export type WeatherSnapshotV1 = {
  readonly location_label: string;
  readonly as_of: string;
  readonly stale: boolean;
  readonly current: {
    readonly temp_f: number;
    readonly summary: string;
  };
  readonly walk_verdict: string;
  readonly uv: {
    readonly index: number;
    readonly grade: WeatherUvGradeV1;
  };
  readonly days5: readonly WeatherDayV1[];
  readonly days7: readonly WeatherDayV1[];
  readonly hourly_uv: readonly {
    readonly hour_local: string;
    readonly index: number;
  }[];
};
