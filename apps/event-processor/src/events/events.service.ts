import { Injectable, BadRequestException, Logger } from '@nestjs/common';
import { PubSubMessageDto } from './dto/pubsub-message.dto';

interface DecodedEvent {
  event: string;
  data: any;
  timestamp?: string;
}

@Injectable()
export class EventsService {
  private readonly logger = new Logger(EventsService.name);

  async processEvent(pubsubMessage: PubSubMessageDto): Promise<any> {
    const { message } = pubsubMessage;

    // Decode base64 message data
    const decodedEvent = this.decodeMessage(message.data);

    // Log the decoded event
    this.logger.log(
      `Processing event: ${JSON.stringify({
        messageId: message.messageId,
        publishTime: message.publishTime,
        subscription: pubsubMessage.subscription,
        eventType: decodedEvent.event,
        eventData: decodedEvent.data,
      })}`,
    );

    // Process the event (placeholder for business logic)
    const result = await this.handleEvent(decodedEvent);

    return result;
  }

  private decodeMessage(base64Data: string): DecodedEvent {
    try {
      // Decode base64 to string
      const jsonString = Buffer.from(base64Data, 'base64').toString('utf-8');

      // Parse JSON
      const parsed = JSON.parse(jsonString);

      // Validate event structure
      if (!parsed || typeof parsed !== 'object') {
        throw new Error('Invalid event structure');
      }

      return parsed as DecodedEvent;
    } catch (error) {
      this.logger.error('Failed to decode message', error.stack);
      throw new BadRequestException('Invalid message format');
    }
  }

  private async handleEvent(event: DecodedEvent): Promise<any> {
    // Placeholder for event processing logic
    // In a real application, you would:
    // 1. Validate the event type
    // 2. Route to appropriate handler
    // 3. Process the event data
    // 4. Store results in database
    // 5. Trigger follow-up actions

    this.logger.log(`Handling event type: ${event.event}`);

    // Example: Different handlers for different event types
    switch (event.event) {
      case 'user.created':
        return this.handleUserCreated(event.data);

      case 'order.placed':
        return this.handleOrderPlaced(event.data);

      case 'test':
        return this.handleTestEvent(event.data);

      default:
        this.logger.warn(`Unknown event type: ${event.event}`);
        return {
          status: 'acknowledged',
          eventType: event.event,
          message: 'Event acknowledged but no handler defined',
        };
    }
  }

  private async handleUserCreated(data: any): Promise<any> {
    this.logger.log(`User created event: ${JSON.stringify(data)}`);
    return {
      status: 'processed',
      eventType: 'user.created',
      userId: data.userId || data.id,
    };
  }

  private async handleOrderPlaced(data: any): Promise<any> {
    this.logger.log(`Order placed event: ${JSON.stringify(data)}`);
    return {
      status: 'processed',
      eventType: 'order.placed',
      orderId: data.orderId || data.id,
    };
  }

  private async handleTestEvent(data: any): Promise<any> {
    this.logger.log(`Test event: ${JSON.stringify(data)}`);
    return {
      status: 'processed',
      eventType: 'test',
      data,
      timestamp: new Date().toISOString(),
    };
  }
}
