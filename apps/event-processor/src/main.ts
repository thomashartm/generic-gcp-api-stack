import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { AppModule } from './app.module';
import { getAppConfig } from './config/app.config';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = getAppConfig();

  // Enable global validation for Pub/Sub message validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
    }),
  );

  // Graceful shutdown
  app.enableShutdownHooks();

  await app.listen(config.port);
  console.log(`Event Processor is running on: http://localhost:${config.port}`);
  console.log(`Environment: ${config.environment}`);
  console.log(`Ready to receive Pub/Sub messages at POST /events`);
}

bootstrap();
