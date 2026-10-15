class ApiConfig {
  static const baseUrl = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'https://api-suho1004.innaim.com');
  static const loginPath = '/api/user/login';
  static const workInfoPath = '/api/user/work_info';
}
