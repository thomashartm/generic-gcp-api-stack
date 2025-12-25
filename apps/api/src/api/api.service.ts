import { Injectable } from '@nestjs/common';

@Injectable()
export class ApiService {
  greet(): object {
    return {
      greeting: 'Hello from the API!',
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
    };
  }
}
