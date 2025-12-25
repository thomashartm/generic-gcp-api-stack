import { Injectable } from '@nestjs/common';
import {
  HealthCheckService,
  TypeOrmHealthIndicator,
  HealthCheck,
} from '@nestjs/terminus';

@Injectable()
export class HealthService {
  constructor(
    private health: HealthCheckService,
    private db: TypeOrmHealthIndicator,
  ) {}

  @HealthCheck()
  async check() {
    try {
      const result = await this.health.check([
        () => this.db.pingCheck('database', { timeout: 5000 }),
      ]);

      return {
        status: 'ok',
        ...result,
        timestamp: new Date().toISOString(),
        version: '1.0.0',
      };
    } catch (error) {
      return {
        status: 'error',
        info: {
          database: {
            status: 'down',
          },
        },
        timestamp: new Date().toISOString(),
        version: '1.0.0',
      };
    }
  }
}
