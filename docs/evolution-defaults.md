# Time evolution defaults

Version 0.1.14 changes the default time evolution factor from `0.000002` to
`0.0000005`. Pollution stays at `0.0000006`, and nest destruction stays at `0.003`.

![Previous and new time evolution defaults over seven running game days](images/time-evolution-defaults.png)

The chart starts at zero evolution and excludes pollution and nest kills. One day
means 24 hours of running simulation; paused server time does not count.

| Running days | Previous default | 0.1.14 default |
| --- | ---: | ---: |
| 1 | 14.7% | 4.1% |
| 2 | 25.7% | 8.0% |
| 3 | 34.1% | 11.5% |
| 4 | 40.9% | 14.7% |
| 5 | 46.4% | 17.8% |
| 6 | 50.9% | 20.6% |
| 7 | 54.7% | 23.2% |

The rate is approximately 75% lower, so a given time-only evolution level takes
about 4 times as long to reach. This does not mean total evolution will be 75%
lower: pollution and nest kills still contribute, and evolution slows as it rises.

For time-only evolution from zero, the approximate curve is
`evolution = (rate * seconds) / (1 + rate * seconds)`. With a time factor of
`0.0000005`, seven days gives approximately 0.2322 (23.2%) evolution.
This models Factorio's diminishing growth; it is not a fixed daily percentage
increase. See the [Factorio evolution mechanics](https://wiki.factorio.com/Enemies#Evolution).

Existing saves keep their stored settings and accumulated evolution. An admin
can apply this rate through **Settings > Mod settings > Map > Time evolution factor**.
