import { Injectable } from '@nestjs/common';

@Injectable()
export class HelloService {
  getHello(): object {
    return {
      message: 'Hello World!',
      timestamp: new Date().toISOString(),
    };
  }

  postHello(data: any): object {
    return {
      message: 'Hello World!',
      method: 'POST',
      receivedData: data,
      timestamp: new Date().toISOString(),
    };
  }
}
