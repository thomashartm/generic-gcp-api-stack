import { Injectable } from '@nestjs/common';

@Injectable()
export class AppService {
  getHello(): object {
    return {
      message: 'Hello from NestJS API!',
      timestamp: new Date().toISOString(),
    };
  }

  postHello(data: any): object {
    return {
      message: 'Hello from NestJS API!',
      method: 'POST',
      receivedData: data,
      timestamp: new Date().toISOString(),
    };
  }
}
