/// Scale factors used to keep money and stock quantities as integers
/// while still representing fractional values.
///
/// Conventions (single source of truth):
///   - [stockScale] = 1000 (1 unit = 1000 in Drift stock ledger, matching DECIMAL(18,3) in PostgreSQL)
///   - [moneyScale] = 1 (1 IDR = 1 in integer, matching DECIMAL(18,2) in PostgreSQL where Rp 15.000 = 15000.00)
///
/// For multi-currency systems with fractional cents, moneyScale could be 100.
/// For Indonesian Rupiah (IDR), 1 Rupiah is the atomic unit without sen.
const int moneyScale = 1;
const int stockScale = 1000;

// Constants for uppercase naming compatibility
// ignore: constant_identifier_names
const int MONEY_SCALE = moneyScale;
// ignore: constant_identifier_names
const int STOCK_SCALE = stockScale;

/// Convert a raw integer (already scaled) to a display-friendly double.
/// e.g. fromScaled(15000, moneyScale) == 15000.0
///     fromScaled(15000, stockScale) == 15.0
double fromScaled(int scaled, int scale) {
  if (scale <= 0) return scaled.toDouble();
  return scaled / scale;
}

/// Convert a fractional double to the scaled integer representation.
/// e.g. toScaled(15000.0, moneyScale) == 15000
///     toScaled(15.0, stockScale)     == 15000
int toScaled(double value, int scale) {
  if (scale <= 0) return value.toInt();
  return (value * scale).round();
}