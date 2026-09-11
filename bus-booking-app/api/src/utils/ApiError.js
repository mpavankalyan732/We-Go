export class ApiError extends Error {
  constructor(message, status = 400, code = 'BAD_REQUEST', details = undefined) {
    super(message);
    this.name = 'ApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  static badRequest(message, details) {
    return new ApiError(message, 400, 'VALIDATION_ERROR', details);
  }

  static notFound(message, details) {
    return new ApiError(message, 404, 'NOT_FOUND', details);
  }

  static conflict(message, details) {
    return new ApiError(message, 409, 'CONFLICT', details);
  }

  static unauthorized(message = 'Missing or invalid API key') {
    return new ApiError(message, 401, 'UNAUTHORIZED');
  }
}
