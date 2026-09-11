const currencyFormatter = new Intl.NumberFormat('en-IN', {
  style: 'currency',
  currency: 'INR',
  maximumFractionDigits: 0
});

export function formatCurrency(amount) {
  return currencyFormatter.format(amount ?? 0);
}

export function formatDisplayDate(isoDate) {
  if (!isoDate) return '';
  const date = new Date(`${isoDate}T00:00:00`);
  return date.toLocaleDateString('en-IN', { weekday: 'short', day: '2-digit', month: 'short', year: 'numeric' });
}

export function todayIsoDate() {
  return new Date().toISOString().slice(0, 10);
}
