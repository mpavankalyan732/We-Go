export default function ErrorBanner({ message }) {
  if (!message) return null;
  return (
    <div className="error-banner" role="alert">
      <strong>Something went wrong:</strong> {message}
    </div>
  );
}
