import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { getAppConfig } from './config/app.config';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = getAppConfig();

  // Enable CORS for external API
  if (config.corsEnabled) {
    app.enableCors();
  }

  // Enable global validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );

  // Graceful shutdown
  app.enableShutdownHooks();

  await app.listen(config.port);
  console.log(`Application is running on: http://localhost:${config.port}`);
  console.log(`Environment: ${config.environment}`);
}

bootstrap();
