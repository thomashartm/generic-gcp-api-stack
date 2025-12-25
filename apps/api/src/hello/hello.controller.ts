import { Controller, Get, Post, Body } from '@nestjs/common';
import { HelloService } from './hello.service';

@Controller('hello')
export class HelloController {
  constructor(private readonly helloService: HelloService) {}

  @Get()
  getHello(): object {
    return this.helloService.getHello();
  }

  @Post()
  postHello(@Body() body: any): object {
    return this.helloService.postHello(body);
  }
}
