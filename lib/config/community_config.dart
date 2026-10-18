class CommunityConfig {
  static const endpoint = String.fromEnvironment('COMMUNITY_API_URL',
      defaultValue: 'https://suho-angel.vercel.app/api/community');
}
