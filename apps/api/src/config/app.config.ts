export interface AppConfig {
  port: number;
  environment: string;
  corsEnabled: boolean;
}

export const getAppConfig = (): AppConfig => {
  return {
    port: parseInt(process.env.PORT || '3000', 10),
    environment: process.env.NODE_ENV || 'development',
    corsEnabled: process.env.CORS_ENABLED !== 'false',
  };
};
