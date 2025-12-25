import {
  Controller,
  Post,
  Body,
  HttpCode,
  HttpStatus,
  Logger,
  BadRequestException,
  InternalServerErrorException,
} from '@nestjs/common';
import { EventsService } from './events.service';
import { PubSubMessageDto } from './dto/pubsub-message.dto';

@Controller('events')
export class EventsController {
  private readonly logger = new Logger(EventsController.name);

  constructor(private readonly eventsService: EventsService) {}

  @Post()
  @HttpCode(HttpStatus.OK)
  async handleEvent(@Body() pubsubMessage: PubSubMessageDto) {
    const startTime = Date.now();
    const { messageId, publishTime } = pubsubMessage.message;

    this.logger.log(
      `Received Pub/Sub message: ${messageId} published at ${publishTime}`,
    );

    try {
      // Decode and process the event
      const result = await this.eventsService.processEvent(pubsubMessage);

      const duration = Date.now() - startTime;
      this.logger.log(
        `Successfully processed message ${messageId} in ${duration}ms`,
      );

      return {
        success: true,
        messageId,
        result,
        processingTime: `${duration}ms`,
      };
    } catch (error) {
      const duration = Date.now() - startTime;
      this.logger.error(
        `Failed to process message ${messageId} after ${duration}ms`,
        error.stack,
      );

      // Return 400 for invalid message format (won't retry)
      if (error instanceof BadRequestException) {
        throw error;
      }

      // Return 500 for processing errors (will retry)
      throw new InternalServerErrorException({
        success: false,
        messageId,
        error: 'Failed to process event',
        processingTime: `${duration}ms`,
      });
    }
  }
}
