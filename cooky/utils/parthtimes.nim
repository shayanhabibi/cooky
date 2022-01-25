## Defines thin time types 
## exported private procedures for convenience from std/times

import std/importutils
import std/strformat

from std/strutils import intToStr, align, alignLeft
from std/times import MonthdayRange, HourRange, MinuteRange, SecondRange,
                      YeardayRange, NanosecondRange, Month, getDaysInMonth,
                      TimeInterval, Time, DateTime, monthday, month, year,
                      dateTime, initDuration, Duration, `+`, `-`

proc assertValidDate(monthday: MonthdayRange, month: Month, year: int)
    {.inline.} =
  assert monthday <= getDaysInMonth(month, year),
    $year & "-" & intToStr(ord(month), 2) & "-" & $monthday &
      " is not a valid date"
      
proc toEpochDay*(monthday: MonthdayRange, month: Month, year: int): int64 =
  ## Get the epoch day from a year/month/day date.
  ## The epoch day is the number of days since 1970/01/01
  ## (it might be negative).
  # Based on http://howardhinnant.github.io/date_algorithms.html

  var (y, m, d) = (year, ord(month), monthday.int)
  if m <= 2:
    y.dec

  let era = (if y >= 0: y else: y-399) div 400
  let yoe = y - era * 400
  let doy = (153 * (m + (if m > 2: -3 else: 9)) + 2) div 5 + d-1
  let doe = yoe * 365 + yoe div 4 - yoe div 100 + doy
  return era * 146097 + doe - 719468

proc fromEpochDay*(epochday: int64):
    tuple[monthday: MonthdayRange, month: Month, year: int] =
  ## Get the year/month/day date from a epoch day.
  ## The epoch day is the number of days since 1970/01/01
  ## (it might be negative).
  # Based on http://howardhinnant.github.io/date_algorithms.html
  var z = epochday
  z.inc 719468
  let era = (if z >= 0: z else: z - 146096) div 146097
  let doe = z - era * 146097
  let yoe = (doe - doe div 1460 + doe div 36524 - doe div 146096) div 365
  let y = yoe + era * 400;
  let doy = doe - (365 * yoe + yoe div 4 - yoe div 100)
  let mp = (5 * doy + 2) div 153
  let d = doy - (153 * mp + 2) div 5 + 1
  let m = mp + (if mp < 10: 3 else: -9)
  return (d.MonthdayRange, m.Month, (y + ord(m <= 2)).int)

type
  ParthDate* {.size: 4.} = object
    day {.bitsize: 5.}: 0u8..31u8
    month {.bitsize: 4.}: 0u8..15u8
    year {.bitsize: 11.}: 0u16..4095u16
  ParthTime* = object
    seconds: int64
  ParthDateTime* = object
    time: ParthTime

proc sanitize*(pd: var ParthDate) =
  if pd.day == 0u8: pd.day = 1u8
  if pd.month == 0u8: pd.month = 1u8
  if pd.year == 0u8: pd.year = 1970u16

proc toParthDate*(tv: sink TimeInterval): ParthDate =
  ## Converts a TimeInterval into the thinner ParthDate
  ## 
  ## TimeInterval size = 80 bytes  
  ## ParthDate size = 4 bytes
  result = ParthDate(day: tv.days.uint8 + 1, month: tv.months.uint8,
                    year: tv.years.uint16)
  result.sanitize

proc toParthTime*(tv: sink TimeInterval): ParthTime =
  ## Converts a TimeInterval into the thinner ParthTime
  ## 
  ## TimeInterval size = 80 bytes  
  ## ParthTime size = 8 bytes
  let epochDay = toEpochDay(tv.days + 1, tv.months.Month, tv.years)
  result.seconds = epochDay * 86_400
  result.seconds.inc tv.hours * 3_600
  result.seconds.inc tv.minutes * 60
  result.seconds.inc tv.seconds

proc toParthTime*(pd: sink ParthDate): ParthTime =
  ## Converts ParthDate to ParthTime
  let epochDay = toEpochDay(pd.day.int, pd.month.Month, pd.year.int)
  result.seconds = epochDay * 86_400

proc toParthDate*(pt: sink ParthTime): ParthDate =
  ## Converts ParthTime to ParthDate
  ## 
  ## WARNING: parthdate is less precise and this precision is lost on conversion.
  ## This is intentional and expected behaviour since ParthDate is designed to be
  ## as thin as possible since date representations will be common in our objects
  let epochDay = pt.seconds div 86_400
  let tplDate = fromEpochDay(epochDay)
  result = ParthDate(day: tplDate.monthday.uint8, month: tplDate.month.uint8,
                    year: tplDate.year.uint16)
  result.sanitize

proc toParthTime*(t: sink Time): ParthTime =
  privateAccess(Time)
  result = ParthTime(seconds: t.seconds)

proc toParthTime*(dt: sink DateTime): ParthTime =
  privateAccess(DateTime)
  let epochDay = toEpochDay(dt.monthday, dt.month, dt.year)
  result.seconds = epochDay * 86_400
  result.seconds.inc dt.hour * 3_600
  result.seconds.inc dt.minute * 60
  result.seconds.inc dt.second

proc toParthDate*(t: sink Time): ParthDate =
  privateAccess(Time)
  let epochDay = t.seconds div 86_400
  let tplDate = fromEpochDay(epochDay)
  result = ParthDate(day: tplDate.monthday.uint8, month: tplDate.month.uint8,
                    year: tplDate.year.uint16)
  result.sanitize

proc toParthDate*(dt: sink DateTime): ParthDate =
  privateAccess(DateTime)
  result = ParthDate(day: dt.monthday.uint8, month: dt.month.uint8,
                    year: dt.year.uint16)
  result.sanitize

proc toDateTime*(pd: ParthDate): DateTime =
  # privateAccess(DateTime)
  let dt = dateTime(pd.year.int, pd.month.Month, pd.day.int)

proc initParthDate*(): ParthDate =
  result = ParthDate(day: 1, month: 1, year: 1940)
proc initParthDate*(day, month, year: int): ParthDate =
  ParthDate(day: day.uint8, month: month.uint8, year: year.uint16)
proc initParthDate*(tv: sink TimeInterval): ParthDate = tv.toParthDate()
proc initParthDate*(dt: sink DateTime): ParthDate = dt.toParthDate()

proc inc*(pd: var ParthDate; days, weeks: int = 0) =
  let dt = dateTime(pd.year.int, pd.month.Month, pd.day.int)
  let dur = initDuration(days = days, weeks = weeks)
  pd = toParthDate(dt + dur)
proc dec*(pd: var ParthDate; days, weeks: int = 0) =
  let dt = dateTime(pd.year.int, pd.month.Month, pd.day.int)
  let dur = initDuration(days = days, weeks = weeks)
  pd = toParthDate(dt - dur)
proc `+`*(pd: ParthDate; days: int): ParthDate =
  let dt = dateTime(pd.year.int, pd.month.Month, pd.day.int)
  let dur = initDuration(days = days)
  result = toParthDate(dt + dur)
proc `-`*(pd: ParthDate; days: int): ParthDate =
  let dt = dateTime(pd.year.int, pd.month.Month, pd.day.int)
  let dur = initDuration(days = days)
  result = toParthDate(dt - dur)


proc `$`*(pd: ParthDate): string =
  let month = align($pd.month, 2, '0')
  let day = align($pd.day, 2, '0')
  fmt"{pd.year}-{month}-{day}"