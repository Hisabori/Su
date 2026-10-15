class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api-suho1004.innaim.com',
  );
  // Set only after matching the existing server contract. No live requests
  // were used to infer these defaults.
  static const contractVerified = bool.fromEnvironment('API_CONTRACT_VERIFIED');
  static const passwordEncoding = String.fromEnvironment('PASSWORD_ENCODING');
  static const loginPath = '/api/user/login';
  static const workInfoPath = '/api/user/work_info';
  static const workResultPath = '/api/user/work_result';
}
