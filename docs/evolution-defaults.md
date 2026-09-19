# Time evolution defaults

Version 0.1.14 changes the default time evolution factor from `0.000002` to
`0.0000007086`. Pollution stays at `0.0000006`, and nest destruction stays at `0.003`.

![Previous and new time evolution defaults over seven running game days](images/time-evolution-defaults.png)

The chart starts at zero evolution and excludes pollution and nest kills. One day
means 24 hours of running simulation; paused server time does not count.

| Running days | Previous default | 0.1.14 default |
| --- | ---: | ---: |
| 1 | 14.7% | 5.8% |
| 2 | 25.7% | 10.9% |
| 3 | 34.1% | 15.5% |
| 4 | 40.9% | 19.7% |
| 5 | 46.4% | 23.4% |
| 6 | 50.9% | 26.9% |
| 7 | 54.7% | 30.0% |

The rate is approximately 64.6% lower, so a given time-only evolution level takes
about 2.82 times as long to reach. This does not mean total evolution will be 64.6%
lower: pollution and nest kills still contribute, and evolution slows as it rises.

For time-only evolution from zero, the approximate curve is
`evolution = (rate * seconds) / (1 + rate * seconds)`. Solving for 0.30 at seven
days gives `rate = 0.30 / (1 - 0.30) / (7 * 86400)`, rounded to `0.0000007086`.
This models Factorio's diminishing growth; it is not a fixed daily percentage
increase. See the [Factorio evolution mechanics](https://wiki.factorio.com/Enemies#Evolution).

Existing saves keep their stored settings and accumulated evolution. An admin
can apply this rate through **Settings > Mod settings > Map > Time evolution factor**.
