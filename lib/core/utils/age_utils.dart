/// Whole years between [dob] and [asOf] (defaults to now) -- the same
/// "have they had their birthday yet this year" calculation used for age
/// restrictions across the app (driver's licences, tax registration,
/// employment, marriage, SASSA Old Age, matric plausibility). The database
/// enforces the same floors as a hard backstop (see migration
/// `enforce_realistic_age_restrictions`) -- this is the friendlier,
/// same-rule client-side check that lets an official see *why* before the
/// request round-trips to a raw Postgres error.
int ageAt(DateTime dob, DateTime asOf) {
  var age = asOf.year - dob.year;
  if (asOf.month < dob.month || (asOf.month == dob.month && asOf.day < dob.day)) {
    age--;
  }
  return age;
}
